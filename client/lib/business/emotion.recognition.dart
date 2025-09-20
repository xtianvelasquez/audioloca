import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/foundation.dart';
import 'package:audioloca/core/secure.storage.dart';

final log = Logger();
final storage = SecureStorageService();
final EmotionRecognition emotionService = EmotionRecognition();

class EmotionResult {
  final String? emotionLabel;
  final double? confidenceScore;
  final String? errorMessage;

  EmotionResult({this.emotionLabel, this.confidenceScore, this.errorMessage});

  bool get isSuccess => emotionLabel != null;
}

class EmotionRecognition {
  static final EmotionRecognition instance = EmotionRecognition._internal();
  factory EmotionRecognition() => instance;
  EmotionRecognition._internal();

  final List<String> emotionLabels = const [
    'surprise',
    'fear',
    'disgust',
    'happiness',
    'sadness',
    'anger',
    'neutral',
    'happily surprised',
    'happily disgusted',
    'sadly fearful',
    'sadly angry',
    'sadly surprised',
    'sadly disgusted',
    'fearfully angry',
    'fearfully surprised',
    'angrily surprised',
    'angrily disgusted',
    'disgustedly surprised',
  ];

  Interpreter? interpreter;
  bool get isModelReady => interpreter != null;

  Future<EmotionResult> requestCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isGranted || status.isLimited) {
      return await predictFromCamera();
    }

    var requestStatus = await Permission.camera.request();
    if (requestStatus.isGranted || requestStatus.isLimited) {
      return await predictFromCamera();
    } else if (requestStatus.isPermanentlyDenied) {
      await openAppSettings();
      return EmotionResult(
        errorMessage: 'Permission permanently denied. Enable it in settings.',
      );
    } else {
      return EmotionResult(errorMessage: 'Camera permission denied.');
    }
  }

  Future<EmotionResult> predictFromCamera() async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.camera,
      );

      if (!isModelReady) {
        return EmotionResult(errorMessage: 'Model not loaded.');
      }

      if (pickedFile == null) {
        return EmotionResult(errorMessage: 'No image captured.');
      }

      final inputImage = InputImage.fromFilePath(pickedFile.path);
      final faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
        ),
      );
      final faces = await faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        return EmotionResult(errorMessage: 'No face detected.');
      } else if (faces.length > 1) {
        return EmotionResult(
          errorMessage: 'Multiple faces detected. Please capture only one.',
        );
      }

      final face = faces.first;
      final boundingBox = face.boundingBox;

      final imageFile = File(pickedFile.path);
      final img.Image? fullImage = await decodeAndPreprocess(imageFile);
      if (fullImage == null) {
        return EmotionResult(
          errorMessage: 'Could not decode image. Please try again.',
        );
      }

      final cropX = boundingBox.left.clamp(0, fullImage.width - 1).toInt();
      final cropY = boundingBox.top.clamp(0, fullImage.height - 1).toInt();
      final cropWidth = (boundingBox.width.toInt()).clamp(
        1,
        fullImage.width - cropX,
      );
      final cropHeight = (boundingBox.height.toInt()).clamp(
        1,
        fullImage.height - cropY,
      );

      final croppedFace = img.copyCrop(
        fullImage,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      final prediction = await predict(croppedFace);

      for (int i = 0; i < emotionLabels.length; i++) {
        log.i(
          '[Emotion] ${emotionLabels[i]}: ${prediction[i].toStringAsFixed(4)}',
        );
      }

      final maxScore = prediction.reduce((a, b) => a > b ? a : b);
      final maxIndex = prediction.indexOf(maxScore);

      for (int i = 0; i < emotionLabels.length; i++) {
        log.i(
          '[Emotion] ${emotionLabels[i]}: ${prediction[i].toStringAsFixed(4)}',
        );
      }

      final fallbackEmotion = 'Neutral';
      final topEmotion = maxScore < 0.5
          ? fallbackEmotion
          : emotionLabels[maxIndex];

      await storage.saveLastMood(topEmotion);

      return EmotionResult(emotionLabel: topEmotion, confidenceScore: maxScore);
    } catch (e, stackTrace) {
      log.e('[Flutter] Error during prediction: $e $stackTrace');
      return EmotionResult(errorMessage: 'Error during prediction: $e');
    }
  }

  Future<img.Image?> decodeAndPreprocess(File imageFile) async {
    return await compute(decodeImageInIsolate, imageFile.path);
  }

  Future<List<double>> predict(img.Image image) async {
    if (!isModelReady) throw Exception('Model not loaded');
    return await compute(runInferenceInIsolate, {
      'image': image,
      'interpreterAddress': interpreter!.address,
    });
  }

  Future<void> loadModel() async {
    try {
      final modelData = await rootBundle.load(
        'assets/mobilenetv2_stage4_final.tflite',
      );
      final tempDir = await getTemporaryDirectory();
      final modelFile = File('${tempDir.path}/mobilenetv2_stage4_final.tflite');
      await modelFile.writeAsBytes(modelData.buffer.asUint8List());

      interpreter = Interpreter.fromFile(modelFile);
      log.i('[Flutter] Model loaded successfully.');
    } catch (e, stackTrace) {
      log.e('[Flutter] Error loading model: $e $stackTrace');
    }
  }

  void disposeInterpreter() {
    interpreter?.close();
    interpreter = null;
  }
}

img.Image? decodeImageInIsolate(String path) {
  final bytes = File(path).readAsBytesSync();
  return img.decodeImage(bytes);
}

List<double> runInferenceInIsolate(Map<String, dynamic> args) {
  final img.Image image = args['image'] as img.Image;
  final int interpreterAddress = args['interpreterAddress'] as int;

  final interpreter = Interpreter.fromAddress(interpreterAddress);

  final resized = img.copyResize(image, width: 224, height: 224);

  final input = List.generate(
    1,
    (_) => List.generate(
      224,
      (y) => List.generate(224, (x) {
        final pixel = resized.getPixel(x, y);

        final r = (pixel.r / 127.5) - 1.0;
        final g = (pixel.g / 127.5) - 1.0;
        final b = (pixel.b / 127.5) - 1.0;

        return [r, g, b];
      }),
    ),
  );

  final output = List.filled(18, 0.0).reshape([1, 18]);
  interpreter.run(input, output);

  return List<double>.from(output[0]);
}

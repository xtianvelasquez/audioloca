import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:audioloca/core/secure.storage.dart';

final log = Logger();
final storage = SecureStorageService();
final EmotionRecognition emotionService = EmotionRecognition();

class EmotionResult {
  final String? emotionLabel;
  final double? confidenceScore;
  final String? errorMessage;
  final List<MapEntry<String, double>>? topEmotions;

  EmotionResult({
    this.emotionLabel,
    this.confidenceScore,
    this.errorMessage,
    this.topEmotions,
  });

  bool get isSuccess => emotionLabel != null;
}

class EmotionRecognition {
  static final EmotionRecognition instance = EmotionRecognition._internal();
  factory EmotionRecognition() => instance;
  EmotionRecognition._internal();

  final List<String> basicLabels = const [
    "Anger",
    "Disgust",
    "Fear",
    "Happiness",
    "Neutral",
    "Sadness",
    "Surprise",
  ];

  Interpreter? basicInterpreter;

  bool get isBasicReady => basicInterpreter != null;
  bool get isModelReady => isBasicReady;

  // -------------------------------------------------------------
  // CAMERA PREDICTION FLOW
  // -------------------------------------------------------------
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
        return EmotionResult(errorMessage: 'Models not loaded.');
      }

      if (pickedFile == null) {
        return EmotionResult(errorMessage: 'No image captured.');
      }

      final inputImage = InputImage.fromFilePath(pickedFile.path);
      final faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
          enableContours: true,
          enableLandmarks: true,
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

      if (_isPartialFace(face)) {
        return EmotionResult(
          errorMessage:
              'Only a portion of your face is visible. Please capture the full face.',
        );
      }

      final boundingBox = face.boundingBox;

      final imageFile = File(pickedFile.path);
      final img.Image? fullImage = await _decodeAndPreprocess(imageFile);

      if (fullImage == null) {
        return EmotionResult(errorMessage: 'Could not decode image.');
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

      final basicPred = await predictBasic(croppedFace);

      final basicSorted = _sortPredictions(basicLabels, basicPred);
      log.i(basicSorted);

      final basicTop = basicSorted.first;
      final fallbackTop = basicSorted[1];

      String chosenEmotion;
      double confidenceScore;

      if (basicTop.value < 0.5) {
        chosenEmotion = fallbackTop.key;
        confidenceScore = fallbackTop.value;
      } else {
        chosenEmotion = basicTop.key;
        confidenceScore = basicTop.value;
      }

      await storage.saveLastMood(chosenEmotion);

      final topBasicEmotions = basicSorted.take(3).toList();

      log.i(
        '[Final Emotion] $chosenEmotion (${confidenceScore.toStringAsFixed(4)})',
      );

      return EmotionResult(
        emotionLabel: chosenEmotion,
        confidenceScore: confidenceScore,
        topEmotions: [...topBasicEmotions],
      );
    } catch (e, stackTrace) {
      log.e('[Flutter] Error during prediction: $e $stackTrace');
      return EmotionResult(errorMessage: 'Error during prediction: $e');
    }
  }

  // -------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------
  List<MapEntry<String, double>> _sortPredictions(
    List<String> labels,
    List<double> predictions,
  ) {
    final sorted = List.generate(
      labels.length,
      (i) => MapEntry(labels[i], predictions[i]),
    )..sort((a, b) => b.value.compareTo(a.value));
    return sorted;
  }

  Future<img.Image?> _decodeAndPreprocess(File imageFile) async {
    return await compute(decodeImageInIsolate, imageFile.path);
  }

  bool _isPartialFace(
    Face face, {
    double minRelativeWidth = 0.15,
    double minRelativeHeight = 0.15,
    int requiredRegions = 2,
    Size? imageSize,
  }) {
    final box = face.boundingBox;

    if (imageSize != null) {
      final minWidth = imageSize.width * minRelativeWidth;
      final minHeight = imageSize.height * minRelativeHeight;
      if (box.width < minWidth || box.height < minHeight) {
        log.w(
          "Partial face: bounding box too small (${box.width}x${box.height}).",
        );
        return true;
      }
    } else {
      if (box.width < 120 || box.height < 120) {
        log.w(
          "Partial face: bounding box too small (${box.width}x${box.height}).",
        );
        return true;
      }
    }

    if (face.contours.isEmpty) {
      log.w("Partial face: no contours available.");
      return true;
    }

    final hasLeftEye =
        face.contours[FaceContourType.leftEye]?.points.isNotEmpty ?? false;
    final hasRightEye =
        face.contours[FaceContourType.rightEye]?.points.isNotEmpty ?? false;
    final hasMouth =
        face.contours[FaceContourType.lowerLipBottom]?.points.isNotEmpty ??
        false;

    final visibleRegions = [
      hasLeftEye,
      hasRightEye,
      hasMouth,
    ].where((x) => x).length;

    if (visibleRegions < requiredRegions) {
      log.w("Partial face detected: visible regions = $visibleRegions");
      return true;
    }

    return false;
  }

  // -------------------------------------------------------------
  // Dual Model Predictions
  // -------------------------------------------------------------
  Future<List<double>> predictBasic(img.Image image) async {
    if (!isBasicReady) throw 'Basic model not loaded.';
    return await compute(runInferenceInIsolate, {
      'image': image,
      'interpreterAddress': basicInterpreter!.address,
    });
  }

  // -------------------------------------------------------------
  // Load Both Models
  // -------------------------------------------------------------
  Future<void> loadModels() async {
    try {
      final tempDir = await getTemporaryDirectory();

      // Basic model
      final basicData = await rootBundle.load(
        'assets/mobilenetv2_rafdb_finetuned.tflite',
      );
      final basicFile = File(
        '${tempDir.path}/mobilenetv2_rafdb_finetuned.tflite',
      );
      await basicFile.writeAsBytes(basicData.buffer.asUint8List());
      basicInterpreter = Interpreter.fromFile(basicFile);
      log.i('[Flutter] Basic model loaded.');
    } catch (e, stackTrace) {
      log.e('[Flutter] Error loading models: $e $stackTrace');
    }
  }

  void disposeInterpreters() {
    basicInterpreter?.close();
    basicInterpreter = null;
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

  final outputShape = interpreter.getOutputTensor(0).shape;
  final output = List.filled(
    outputShape.reduce((a, b) => a * b),
    0.0,
  ).reshape(outputShape);

  interpreter.run(input, output);

  return List<double>.from(output[0]);
}

import 'dart:io';
import 'package:logger/logger.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:audioloca/core/secure.storage.dart';

final log = Logger();
final EmotionService emotionService = EmotionService();
final storage = SecureStorageService();

class EmotionResult {
  final int? emotionId;
  final String? emotionLabel;
  final double? confidenceScore;
  final String? errorMessage;

  EmotionResult({
    this.emotionId,
    this.emotionLabel,
    this.confidenceScore,
    this.errorMessage,
  });

  bool get isSuccess => emotionId != null;
}

class EmotionService {
  static final EmotionService _instance = EmotionService._internal();
  factory EmotionService() => _instance;
  EmotionService._internal();

  final List<String> emotionLabels = const [
    'angry',
    'disgust',
    'fear',
    'happy',
    'sad',
    'surprise',
    'neutral',
  ];

  Interpreter? _interpreter;
  bool get isModelReady => _interpreter != null;

  Future<EmotionResult> requestCameraPermission() async {
    var status = await Permission.camera.status;

    if (status.isGranted || status.isLimited) {
      log.i('[Flutter] Camera permission already granted/limited.');
      return await predictFromCamera();
    }

    var requestStatus = await Permission.camera.request();

    if (requestStatus.isGranted || requestStatus.isLimited) {
      log.i('[Flutter] Camera permission granted/limited.');
      return await predictFromCamera();
    } else if (requestStatus.isPermanentlyDenied) {
      log.i('[Flutter] Camera permission permanently denied.');
      await openAppSettings();
      return EmotionResult(
        errorMessage:
            'Permission permanently denied. Please enable it in settings.',
      );
    } else {
      log.i('[Flutter] Camera permission denied.');
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
        return EmotionResult(
          errorMessage: 'Model not loaded. Please load the model first.',
        );
      }

      if (pickedFile != null) {
        log.i('[Flutter] Image captured: ${pickedFile.path}');
        File imageFile = File(pickedFile.path);
        final bytes = await imageFile.readAsBytes();
        final img.Image? capturedImage = img.decodeImage(bytes);

        if (capturedImage != null) {
          log.i(
            '[Flutter] Original Image: ${capturedImage.width}x${capturedImage.height}',
          );

          final prediction = await predict(capturedImage);
          if (prediction.every((score) => score == 0.0)) {
            log.w(
              '[Flutter] Prediction returned all zeros — possible model issue.',
            );
          }
          for (int i = 0; i < emotionLabels.length; i++) {
            log.i(
              '[Flutter] ${emotionLabels[i]}: ${prediction[i].toStringAsFixed(4)}',
            );
          }

          final maxScore = prediction.reduce((a, b) => a > b ? a : b);
          final maxIndex = prediction.indexOf(maxScore);

          final topEmotion = emotionLabels[maxIndex];
          final topScore = prediction[maxIndex].toStringAsFixed(4);

          log.i('[Flutter] Top Emotion: $topEmotion ($topScore)');
          await storage.saveLastMood(topEmotion);

          return EmotionResult(
            emotionId: maxIndex + 1,
            emotionLabel: topEmotion,
            confidenceScore: maxScore,
          );
        } else {
          log.d('[Flutter] Could not decode image.');
          return EmotionResult(errorMessage: 'Could not decode image.');
        }
      } else {
        log.d('[Flutter] No image captured.');
        return EmotionResult(errorMessage: 'No image captured.');
      }
    } catch (e, stackTrace) {
      log.e('[Flutter] Error during camera prediction: $e $stackTrace');
      return EmotionResult(errorMessage: 'Error during prediction: $e');
    }
  }

  Future<List<double>> predict(img.Image cameraImage) async {
    if (!isModelReady) {
      throw Exception('Model not loaded');
    }

    return await compute(_runInferenceInIsolate, {
      'image': cameraImage,
      'interpreterAddress': _interpreter!.address,
    });
  }

  Future<void> loadModel() async {
    try {
      final modelData = await rootBundle.load('assets/emotion_model.tflite');
      final tempDir = await getTemporaryDirectory();
      final modelFile = File('${tempDir.path}/emotion_model.tflite');
      await modelFile.writeAsBytes(modelData.buffer.asUint8List());

      _interpreter = Interpreter.fromFile(modelFile);
      log.i('[Flutter] Model loaded successfully');

      var inputShape = _interpreter!.getInputTensor(0).shape;
      var inputType = _interpreter!.getInputTensor(0).type;
      log.i('[Flutter] Input Shape: $inputShape');
      log.i('[Flutter] Input Type: $inputType');
    } catch (e, stackTrace) {
      log.e('[Flutter] Error loading model: $e $stackTrace');
    }
  }

  void disposeInterpreter() {
    _interpreter?.close();
    _interpreter = null;
  }
}

List<double> _runInferenceInIsolate(Map<String, dynamic> args) {
  final img.Image image = args['image'] as img.Image;
  final int interpreterAddress = args['interpreterAddress'] as int;

  final interpreter = Interpreter.fromAddress(interpreterAddress);

  final resized = img.copyResize(image, width: 64, height: 64);
  final gray = img.grayscale(resized);

  List<List<List<List<double>>>> input = [
    List.generate(
      64,
      (y) => List.generate(64, (x) => [gray.getPixel(x, y).luminance / 255.0]),
    ),
  ];

  var output = List.filled(7, 0.0).reshape([1, 7]);
  interpreter.run(input, output);

  return List<double>.from(output[0]);
}

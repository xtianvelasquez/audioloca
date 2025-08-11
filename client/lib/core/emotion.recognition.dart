import 'dart:io';
import 'package:logger/logger.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

final log = Logger();
final EmotionService emotionService = EmotionService();

class EmotionService {
  static final EmotionService _instance = EmotionService._internal();
  factory EmotionService() => _instance;
  EmotionService._internal();

  final List<String> emotionLabels = const [
    'Angry',
    'Disgust',
    'Fear',
    'Happy',
    'Sad',
    'Surprise',
    'Neutral',
  ];

  late Interpreter _interpreter;

  bool get isModelReady => _interpreter.address != 0;

  Future<void> requestCameraPermission() async {
    var status = await Permission.camera.request();
    if (status.isGranted) {
      log.i('[Flutter] Camera permission granted.');
      await predictFromCamera();
    } else if (status.isDenied || status.isPermanentlyDenied) {
      log.i('[Flutter] Camera permission denied.');
      await openAppSettings();
    }
  }

  Future<void> predictFromCamera() async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.camera,
      );

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
          for (int i = 0; i < emotionLabels.length; i++) {
            log.i(
              '[Flutter] ${emotionLabels[i]}: ${prediction[i].toStringAsFixed(4)}',
            );
          }
        } else {
          log.d('[Flutter] Could not decode image.');
        }
      } else {
        log.d('[Flutter] No image captured.');
      }
    } catch (e, stackTrace) {
      log.e('[Flutter] Error during camera prediction: $e $stackTrace');
    }
  }

  Future<List<double>> predict(img.Image cameraImage) async {
    if (!isModelReady) {
      throw Exception('Model not loaded');
    }

    return await compute(_runInferenceInIsolate, {
      'image': cameraImage,
      'interpreterAddress': _interpreter.address,
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

      var inputShape = _interpreter.getInputTensor(0).shape;
      var inputType = _interpreter.getInputTensor(0).type;
      log.i('[Flutter] Input Shape: $inputShape');
      log.i('[Flutter] Input Type: $inputType');
    } catch (e, stackTrace) {
      log.e('[Flutter] Error loading model: $e $stackTrace');
    }
  }

  void disposeInterpreter() {
    _interpreter.close();
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

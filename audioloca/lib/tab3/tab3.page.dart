import 'package:logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:audioloca/theme.dart';
import 'package:audioloca/player/views/mini.player.dart';

final log = Logger();

class Tab3 extends StatefulWidget {
  const Tab3({super.key});
  @override
  State<Tab3> createState() => Tab3State();
}

class Tab3State extends State<Tab3> with AutomaticKeepAliveClientMixin {
  CameraController? _cameraController;
  String _predictedEmotion = "Initializing...";
  double _confidence = 0.0;
  String _debugInfo = "";
  bool _isProcessing = false;
  bool _isInitialized = false;
  int _frameCount = 0;

  static const platform = MethodChannel('com.example.audioloca/emotion');

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeAll();
  }

  Future<void> _initializeAll() async {
    try {
      log.i("Starting native emotion detection initialization...");

      // Initialize camera first
      await _initCamera();

      // Initialize native detector
      final bool initialized = await platform.invokeMethod(
        'initEmotionDetector',
      );

      if (initialized) {
        _isInitialized = true;
        log.i("Native emotion detector initialized successfully!");

        if (mounted) {
          setState(() {
            _predictedEmotion = "Ready - show your face";
          });
        }
      } else {
        throw Exception("Failed to initialize native detector");
      }
    } catch (e, stackTrace) {
      log.e("Initialization error: $e $stackTrace");
      if (mounted) {
        setState(() {
          _predictedEmotion = "Error: ${e.toString()}";
        });
      }
    }
  }

  Future<void> _initCamera() async {
    try {
      log.i("Getting cameras...");
      final cameras = await availableCameras();
      log.i("Found ${cameras.length} cameras");

      // Find front camera
      CameraDescription? frontCamera;
      for (var camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          frontCamera = camera;
          break;
        }
      }

      if (frontCamera == null && cameras.isNotEmpty) {
        frontCamera = cameras.first;
      } else if (frontCamera == null) {
        throw Exception("No cameras available.");
      }

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      // Start frame processing
      _cameraController!.startImageStream((CameraImage image) {
        if (_isProcessing || !_isInitialized) return;

        // Frame skipping for performance
        _frameCount++;
        if (_frameCount % 3 != 0) return;

        _isProcessing = true;

        // Send to native for processing
        Future.microtask(() async {
          try {
            await _processFrameWithNative(image);
          } catch (e, stackTrace) {
            log.e("Native processing error: $e $stackTrace");
          } finally {
            _isProcessing = false;
          }
        });
      });

      if (mounted) setState(() {});
    } catch (e, stackTrace) {
      log.e("Camera initialization error: $e $stackTrace");
      if (mounted) {
        setState(() {
          _predictedEmotion = "Camera error: ${e.toString()}";
        });
      }
    }
  }

  Future<void> _processFrameWithNative(CameraImage image) async {
    try {
      // Prepare image data for native processing
      final Map<String, dynamic> imageData = {
        'yPlane': image.planes[0].bytes,
        'uPlane': image.planes[1].bytes,
        'vPlane': image.planes[2].bytes,
        'width': image.width,
        'height': image.height,
        'yRowStride': image.planes[0].bytesPerRow,
        'uRowStride': image.planes[1].bytesPerRow,
        'vRowStride': image.planes[2].bytesPerRow,
        'uPixelStride': image.planes[1].bytesPerPixel ?? 1,
        'vPixelStride': image.planes[2].bytesPerPixel ?? 1,
        'sensorOrientation': _cameraController!.description.sensorOrientation,
      };

      // Call native method
      final Map<dynamic, dynamic> result = await platform.invokeMethod(
        'processFrame',
        imageData,
      );

      // Parse results
      final String emotion = result['emotion'] ?? "Unknown";
      final double confidence = (result['confidence'] ?? 0.0).toDouble();
      final bool hasFace = result['hasFace'] ?? false;
      final bool multipleFaces = result['multipleFaces'] ?? false;
      final String? debugInfo = result['debugInfo'];

      // Update UI
      if (mounted) {
        setState(() {
          if (hasFace) {
            _predictedEmotion = emotion;
            _confidence = confidence;
          } else if (multipleFaces) {
            _predictedEmotion = "Multiple faces detected";
            _confidence = 0.0;
          } else {
            _predictedEmotion = "No face detected";
            _confidence = 0.0;
          }
          _debugInfo = debugInfo ?? "";
        });
      }
    } catch (e, stackTrace) {
      log.e("Native processing error: $e $stackTrace");
      if (mounted) {
        setState(() {
          _debugInfo = "Error: ${e.toString()}";
        });
      }
    }
  }

  @override
  void dispose() {
    log.i("Disposing resources...");
    // Clean up native resources
    platform.invokeMethod('disposeEmotionDetector');
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("AudioLoca"),
        backgroundColor: AppColors.color1,
        foregroundColor: AppColors.light,
        elevation: 0,
      ),
      body: _cameraController == null || !_cameraController!.value.isInitialized
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    _predictedEmotion,
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                CameraPreview(_cameraController!),
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.color1.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _predictedEmotion,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(_confidence * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 15,
                            ),
                          ),
                          if (_debugInfo.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              _debugInfo,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

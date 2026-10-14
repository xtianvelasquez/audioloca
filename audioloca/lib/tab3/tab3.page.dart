import 'package:logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:audioloca/theme.dart';
import 'package:audioloca/player/views/mini.player.dart';
import 'package:audioloca/tabs/tabs.routing.dart';
import 'package:audioloca/core/utils.dart';

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
          _predictedEmotion = "Error: ${sanitizeErrorMessage(e)}";
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
          _predictedEmotion = "Camera error: ${sanitizeErrorMessage(e)}";
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
          _debugInfo = "Error: ${sanitizeErrorMessage(e)}";
        });
      }
    }
  }

  @override
  void dispose() {
    log.i("Disposing resources...");
    platform.invokeMethod('disposeEmotionDetector');
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: AppColors.bgMid,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  ClayCircleButton(
                    icon: Icons.arrow_back_rounded,
                    size: 40,
                    onPressed: () {
                      TabsRouting.of(context)?.setTab(0);
                    },
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Emotion Scanner",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.dark,
                    ),
                  ),
                ],
              ),
            ),

            // Camera Area inside Clay Card
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Container(
                  decoration: ClayDecorations.card(radius: 26),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: _cameraController == null ||
                            !_cameraController!.value.isInitialized
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(
                                  color: AppColors.primaryPurple,
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  _predictedEmotion,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              CameraPreview(_cameraController!),

                              // Top Live Indicator Pill
                              Positioned(
                                top: 16,
                                left: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.redAccent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        "LIVE",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Floating Clay Card Result at bottom
                              Positioned(
                                bottom: 20,
                                left: 16,
                                right: 16,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.shadowDark.withValues(
                                          alpha: 0.25,
                                        ),
                                        offset: const Offset(0, 8),
                                        blurRadius: 18,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _predictedEmotion,
                                        style: const TextStyle(
                                          color: AppColors.dark,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.pillBg,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: Text(
                                          '${(_confidence * 100).toStringAsFixed(1)}% Confidence',
                                          style: const TextStyle(
                                            color: AppColors.primaryPurple,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (_debugInfo.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          _debugInfo,
                                          style: TextStyle(
                                            color: AppColors.textSecondary
                                                .withValues(alpha: 0.8),
                                            fontSize: 11,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

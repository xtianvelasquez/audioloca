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
  final bool isActive;
  const Tab3({super.key, this.isActive = false});

  @override
  State<Tab3> createState() => Tab3State();
}

class Tab3State extends State<Tab3>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  CameraController? _cameraController;
  String _predictedEmotion = "Initializing...";
  double _confidence = 0.0;
  String _debugInfo = "";
  bool _isProcessing = false;
  bool _isInitialized = false;
  bool _isCameraInitializing = false;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  int _frameCount = 0;

  static const platform = MethodChannel('com.example.audioloca/emotion');

  @override
  bool get wantKeepAlive => true;

  bool get _isAppResumed => _lifecycleState == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAll();
  }

  Future<void> _initializeAll() async {
    try {
      log.i("Starting native emotion detection initialization...");

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

        // Only start camera if this tab is active and app is in foreground
        if (mounted && widget.isActive && _isAppResumed) {
          await _initCamera();
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
    if (_isCameraInitializing || !widget.isActive || !_isAppResumed) return;
    _isCameraInitializing = true;

    try {
      log.i("Getting cameras...");
      final cameras = await availableCameras();
      log.i("Found ${cameras.length} cameras");

      if (!mounted || !widget.isActive || !_isAppResumed) {
        return;
      }

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

      // Dispose existing controller if any
      if (_cameraController != null) {
        try {
          if (_cameraController!.value.isStreamingImages) {
            await _cameraController!.stopImageStream();
          }
          await _cameraController!.dispose();
        } catch (_) {}
        _cameraController = null;
      }

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();

      if (!mounted || !widget.isActive || !_isAppResumed) {
        await controller.dispose();
        return;
      }

      _cameraController = controller;
      if (mounted) {
        setState(() {});
      }

      await _startImageStream();
    } catch (e, stackTrace) {
      log.e("Camera initialization error: $e $stackTrace");
      if (mounted) {
        setState(() {
          _predictedEmotion = "Camera error: ${sanitizeErrorMessage(e)}";
        });
      }
    } finally {
      _isCameraInitializing = false;
    }
  }

  Future<void> _startImageStream() async {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isStreamingImages ||
        !widget.isActive ||
        !_isAppResumed) {
      return;
    }

    try {
      await controller.startImageStream((CameraImage image) {
        if (!mounted || !widget.isActive || !_isAppResumed) {
          _stopImageStream();
          return;
        }

        if (_isProcessing || !_isInitialized) return;

        // Frame skipping for performance
        _frameCount++;
        if (_frameCount % 3 != 0) return;

        _isProcessing = true;

        // Send to native for processing
        Future.microtask(() async {
          try {
            if (mounted && widget.isActive && _isAppResumed) {
              await _processFrameWithNative(image);
            }
          } catch (e, stackTrace) {
            log.e("Native processing error: $e $stackTrace");
          } finally {
            _isProcessing = false;
          }
        });
      });
    } catch (e) {
      log.w("Error starting image stream: $e");
    }
  }

  Future<void> _stopImageStream() async {
    final controller = _cameraController;
    _isProcessing = false;
    if (controller != null &&
        controller.value.isInitialized &&
        controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } catch (e) {
        log.w("Error stopping image stream: $e");
      }
    }
  }

  Future<void> _pauseCamera() async {
    await _stopImageStream();
    final controller = _cameraController;
    if (controller != null && controller.value.isInitialized) {
      try {
        await controller.pausePreview();
      } catch (e) {
        log.w("Error pausing camera preview: $e");
      }
    }
  }

  Future<void> _resumeCamera() async {
    if (!mounted || !widget.isActive || !_isAppResumed) return;

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      await _initCamera();
      return;
    }

    try {
      await controller.resumePreview();
      await _startImageStream();
    } catch (e) {
      log.w("Failed to resume preview, re-initializing: $e");
      await _stopAndDisposeCamera();
      if (mounted && widget.isActive && _isAppResumed) {
        await _initCamera();
      }
    }
  }

  Future<void> _stopAndDisposeCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    _isProcessing = false;

    if (controller != null) {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (e) {
        log.w("Error stopping image stream during dispose: $e");
      }
      try {
        await controller.dispose();
      } catch (e) {
        log.w("Error disposing camera controller: $e");
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(Tab3 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _resumeCamera();
      } else {
        _pauseCamera();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      if (widget.isActive) {
        _resumeCamera();
      }
    } else {
      _stopAndDisposeCamera();
    }
  }

  Future<void> _processFrameWithNative(CameraImage image) async {
    try {
      final controller = _cameraController;
      if (controller == null || !controller.value.isInitialized) return;

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
        'sensorOrientation': controller.description.sensorOrientation,
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

      // Update UI only if still mounted and active
      if (mounted && widget.isActive && _isAppResumed) {
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
      if (mounted && widget.isActive && _isAppResumed) {
        setState(() {
          _debugInfo = "Error: ${sanitizeErrorMessage(e)}";
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    log.i("Disposing resources...");
    _stopAndDisposeCamera();
    platform.invokeMethod('disposeEmotionDetector');
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

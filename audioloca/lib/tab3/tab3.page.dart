import 'dart:async';
import 'package:logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:audioloca/theme.dart';
import 'package:audioloca/player/views/mini.player.dart';
import 'package:audioloca/tabs/tabs.routing.dart';
import 'package:audioloca/core/utils.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/local/models/audio.model.dart';
import 'package:audioloca/local/local.recommender.dart';
import 'package:audioloca/spotify/models/track.model.dart';
import 'package:audioloca/spotify/spotify.recommender.dart';
import 'package:audioloca/tab1/tab1.widgets/local.recommender.dart';
import 'package:audioloca/tab1/tab1.widgets/spotify.recommender.dart';

final log = Logger();
final storage = SecureStorageService();
final localRecommender = LocalRecommender();
final spotifyRecommender = SpotifyRecommender();

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
  bool _isProcessing = false;
  bool _isInitialized = false;
  bool _isCameraInitializing = false;
  bool _isCameraTransitioning = false;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  int _frameCount = 0;

  // Emotion Recommendation state
  List<Audio> localTracks = [];
  List<SpotifyTrack> spotifyTracks = [];
  bool isLoadingRecommendations = false;
  String? accessToken;
  String? _lastRecommendedEmotion;
  Timer? _emotionDebounceTimer;

  static const platform = MethodChannel('com.example.audioloca/emotion');

  @override
  bool get wantKeepAlive => true;

  bool get _isAppResumed => _lifecycleState == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitialMoodRecommendations();
    _initializeAll();
  }

  Future<void> _loadInitialMoodRecommendations() async {
    try {
      final lastMood = await storage.getLastMood();
      if (lastMood != null && lastMood.isNotEmpty) {
        await _fetchMoodRecommendations(lastMood);
      }
    } catch (e) {
      log.w("Failed to load initial mood in Camera tab: $e");
    }
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

  Future<void> _handleTabActivated() async {
    while (_isCameraTransitioning) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted || !widget.isActive) return;
    }
    _isCameraTransitioning = true;
    try {
      if (mounted && widget.isActive && _isAppResumed) {
        await _resumeCamera();
      }
    } finally {
      _isCameraTransitioning = false;
    }
  }

  Future<void> _handleTabDeactivated() async {
    while (_isCameraTransitioning) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    _isCameraTransitioning = true;
    try {
      await _pauseCamera();
    } finally {
      _isCameraTransitioning = false;
    }
  }

  @override
  void didUpdateWidget(Tab3 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _handleTabActivated();
      } else {
        _emotionDebounceTimer?.cancel();
        _handleTabDeactivated();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      if (widget.isActive) {
        _handleTabActivated();
      }
    } else {
      _emotionDebounceTimer?.cancel();
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
        });

        // Trigger debounced recommendations if a valid emotion was detected with good confidence
        if (hasFace &&
            confidence >= 0.5 &&
            _canRecommend(emotion) &&
            emotion.toLowerCase() != _lastRecommendedEmotion) {
          _emotionDebounceTimer?.cancel();
          _emotionDebounceTimer = Timer(const Duration(milliseconds: 1400), () {
            if (mounted &&
                widget.isActive &&
                _isAppResumed &&
                _predictedEmotion.toLowerCase() == emotion.toLowerCase()) {
              _fetchMoodRecommendations(emotion);
            }
          });
        }
      }
    } catch (e, stackTrace) {
      log.e("Native processing error: $e $stackTrace");
    }
  }

  Future<void> _fetchMoodRecommendations(
    String emotion, {
    bool forceRefresh = false,
  }) async {
    final cleanEmotion = emotion.trim().toLowerCase();
    if (cleanEmotion.isEmpty ||
        cleanEmotion == "unknown" ||
        cleanEmotion.contains("no face") ||
        cleanEmotion.contains("multiple faces") ||
        cleanEmotion.contains("initializing") ||
        cleanEmotion.contains("ready") ||
        cleanEmotion.contains("error")) {
      return;
    }

    if (!forceRefresh &&
        _lastRecommendedEmotion == cleanEmotion &&
        (localTracks.isNotEmpty || spotifyTracks.isNotEmpty)) {
      return;
    }

    _lastRecommendedEmotion = cleanEmotion;

    if (mounted) {
      setState(() => isLoadingRecommendations = true);
    }

    try {
      await storage.saveLastMood(emotion);

      accessToken ??= await spotifyRecommender.getValidAccessToken();

      final local = await localRecommender.fetchMoodRecommendationsFromLocal();

      List<SpotifyTrack> spotify = [];
      if (accessToken != null) {
        final rawSpotify =
            await spotifyRecommender.fetchMoodRecommendationsFromSpotify(
          forceRefresh: forceRefresh,
        );
        spotify =
            rawSpotify.map((json) => SpotifyTrack.fromJson(json)).toList();
      }

      if (mounted) {
        setState(() {
          localTracks = local;
          spotifyTracks = spotify;
        });
      }
    } catch (e, stackTrace) {
      log.e("Failed to fetch mood recommendations in Camera tab: $e $stackTrace");
    } finally {
      if (mounted) {
        setState(() => isLoadingRecommendations = false);
      }
    }
  }

  String _getEmotionEmoji(String emotion) {
    final lower = emotion.toLowerCase();
    if (lower.contains('happy') || lower.contains('happiness')) return '😊';
    if (lower.contains('sad')) return '😢';
    if (lower.contains('anger') || lower.contains('angry')) return '😠';
    if (lower.contains('fear')) return '😨';
    if (lower.contains('disgust')) return '🤢';
    if (lower.contains('surprise')) return '😲';
    if (lower.contains('neutral')) return '😐';
    return '🙂';
  }

  bool _canRecommend(String emotion) {
    final lower = emotion.toLowerCase();
    return lower == 'happiness' ||
        lower == 'sadness' ||
        lower == 'anger' ||
        lower == 'fear' ||
        lower == 'disgust' ||
        lower == 'surprise' ||
        lower == 'neutral';
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  void dispose() {
    _emotionDebounceTimer?.cancel();
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
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
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
                    const Expanded(
                      child: Text(
                        "Emotion Scanner",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.dark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_canRecommend(_predictedEmotion)) ...[
                      const SizedBox(width: 8),
                      ClayCircleButton(
                        icon: Icons.refresh_rounded,
                        size: 40,
                        onPressed: () => _fetchMoodRecommendations(
                          _predictedEmotion,
                          forceRefresh: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 4),

              // Camera Viewfinder inside Clay Card
              Container(
                height: 300,
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
                              top: 14,
                              left: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
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

                            // Floating Current Emotion Pill over Camera
                            Positioned(
                              bottom: 14,
                              left: 14,
                              right: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.94),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.shadowDark.withValues(
                                        alpha: 0.22,
                                      ),
                                      offset: const Offset(0, 6),
                                      blurRadius: 14,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: const BoxDecoration(
                                        color: AppColors.pillBg,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          _getEmotionEmoji(_predictedEmotion),
                                          style: const TextStyle(fontSize: 20),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _predictedEmotion,
                                            style: const TextStyle(
                                              color: AppColors.dark,
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (_confidence > 0)
                                            Text(
                                              '${(_confidence * 100).toStringAsFixed(1)}% Confidence',
                                              style: const TextStyle(
                                                color: AppColors.primaryPurple,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (_canRecommend(_predictedEmotion))
                                      ClayCircleButton(
                                        icon: Icons.music_note_rounded,
                                        size: 36,
                                        onPressed: () =>
                                            _fetchMoodRecommendations(
                                          _predictedEmotion,
                                          forceRefresh: true,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // Recommendations Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      "Mood-Based Recommendations",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isLoadingRecommendations)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryPurple,
                      ),
                    ),
                ],
              ),
              if (_lastRecommendedEmotion != null) ...[
                const SizedBox(height: 4),
                Text(
                  "Curated for ${_capitalize(_lastRecommendedEmotion!)} mood",
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const SizedBox(height: 14),

              if (isLoadingRecommendations &&
                  localTracks.isEmpty &&
                  spotifyTracks.isEmpty)
                Container(
                  height: 120,
                  decoration: ClayDecorations.card(radius: 20),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryPurple,
                    ),
                  ),
                )
              else if (localTracks.isEmpty && spotifyTracks.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: ClayDecorations.card(radius: 20),
                  child: Column(
                    children: const [
                      Icon(
                        Icons.face_retouching_natural_rounded,
                        size: 40,
                        color: AppColors.primaryPurple,
                      ),
                      SizedBox(height: 12),
                      Text(
                        "Point the camera at your face to detect your emotion and get instant song recommendations!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                if (localTracks.isNotEmpty) ...[
                  Row(
                    children: const [
                      Icon(
                        Icons.audiotrack_rounded,
                        color: AppColors.primaryPurple,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        "Local Tracks",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.dark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LocalListView(allTracks: localTracks),
                ],

                if (accessToken != null && spotifyTracks.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: const [
                      Icon(
                        Icons.music_note_rounded,
                        color: AppColors.primaryPurple,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        "Spotify Recommendations",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.dark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SpotifyListView(allTracks: spotifyTracks),
                ],
              ],

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

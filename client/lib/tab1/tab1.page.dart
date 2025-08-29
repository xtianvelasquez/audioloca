import 'package:logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:audioloca/core/emotion.recognition.dart';
import 'package:audioloca/services/spotify.service.dart';
import 'package:audioloca/tab1/tab1.widgets/emotion.recommender.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/models/audio.model.dart';
import 'package:audioloca/global/mini.player.dart';

final log = Logger();
final storage = SecureStorageService();

class Tab1 extends StatefulWidget {
  const Tab1({super.key});
  @override
  State<Tab1> createState() => Tab1State();
}

class Tab1State extends State<Tab1> {
  String? detectedMood;
  List<SpotifyTrack> tracks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks({bool forceRefresh = false}) async {
    setState(() {
      isLoading = true;
      tracks = [];
    });

    try {
      final rawResponse = await SpotifyService().fetchMoodRecommendations(
        forceRefresh: forceRefresh,
      );
      final parsedTracks = rawResponse
          .map((json) => SpotifyTrack.fromJson(json as Map<String, dynamic>))
          .toList();

      setState(() {
        tracks = parsedTracks;
        isLoading = false;
      });
    } catch (e) {
      log.e('Failed to fetch or parse tracks: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tab 1')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final result = await emotionService.requestCameraPermission();

                if (result.isSuccess) {
                  log.i('[Flutter] Emotion ID: ${result.emotionId}');
                  log.i('[Flutter] Label: ${result.emotionLabel}');
                  log.i(
                    '[Flutter] Confidence: ${result.confidenceScore?.toStringAsFixed(4)}',
                  );

                  // Save mood to storage
                  if (result.emotionLabel != null) {
                    await storage.saveLastMood(result.emotionLabel!);
                    setState(() {
                      detectedMood = result.emotionLabel!;
                    });
                    await _loadTracks(forceRefresh: true);
                  } else {
                    log.w(
                      '[Flutter] No emotion label returned. Skipping mood save.',
                    );
                  }
                } else {
                  log.i('[Flutter] Error: ${result.errorMessage}');
                }
              },
              child: const Text('SCAN MY MOOD'),
            ),
            const SizedBox(height: 20),
            if (detectedMood != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  "Detected Mood: ${detectedMood!.toUpperCase()}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : AudioListView(allTracks: tracks),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

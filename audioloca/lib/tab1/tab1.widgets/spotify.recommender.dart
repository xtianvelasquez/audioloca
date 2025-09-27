import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import 'package:audioloca/theme.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/core/utils.dart';
import 'package:audioloca/business/location.services.dart';
import 'package:audioloca/services/stream.service.dart';
import 'package:audioloca/services/tap.service.dart';
import 'package:audioloca/spotify/models/track.model.dart';
import 'package:audioloca/widgets/audio.card.dart';

final log = Logger();
final storage = SecureStorageService();
final streamServices = StreamServices();
final locationServices = LocationServices();
final tapServices = TapServices();

class SpotifyListView extends StatefulWidget {
  final List<SpotifyTrack> allTracks;

  const SpotifyListView({super.key, required this.allTracks});

  @override
  State<SpotifyListView> createState() => SpotifyListViewState();
}

class SpotifyListViewState extends State<SpotifyListView> {
  static const int initialLimit = 10;
  static const int increment = 10;

  late List<SpotifyTrack> visibleTracks;
  bool isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    visibleTracks = widget.allTracks.take(initialLimit).toList();
  }

  void loadMore() async {
    if (isLoadingMore) return;
    setState(() => isLoadingMore = true);

    await Future.delayed(const Duration(milliseconds: 300));
    final nextLimit = visibleTracks.length + increment;
    setState(() {
      visibleTracks = widget.allTracks
          .take(nextLimit.clamp(0, widget.allTracks.length))
          .toList();
      isLoadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: visibleTracks.length,
          itemBuilder: (context, index) {
            final track = visibleTracks[index];
            return AudioListItem(
              imageUrl: resolveImageUrl(track.albumImageUrl),
              title: track.name,
              subtitle: track.artist,
              streamCount: track.streamCount ?? 0,
              duration: formatSpotifyTrackDuration(track.durationMs),
              onTap: () => tapServices.handleSpotifyTrackTap(
                track,
                context,
                context.mounted,
              ),
            );
          },
        ),

        if (visibleTracks.length < widget.allTracks.length)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: isLoadingMore
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: AppColors.color1,
                      strokeWidth: 2,
                    ),
                  )
                : GestureDetector(
                    onTap: loadMore,
                    child: const Text(
                      'Load More',
                      style: TextStyle(
                        color: AppColors.color1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
      ],
    );
  }
}

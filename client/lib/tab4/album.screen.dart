import 'package:flutter/material.dart';
import 'package:audioloca/environment.dart';
import 'package:audioloca/services/album.service.dart';
import 'package:audioloca/services/audio.service.dart';
import 'package:audioloca/services/local.player.service.dart';
import 'package:audioloca/models/album.model.dart';
import 'package:audioloca/models/audio.model.dart';
import 'package:audioloca/tab4/tab4.widgets/album.audio.dart';
import 'package:audioloca/tab4/tab4.widgets/album.card.dart';
import 'package:audioloca/theme.dart';
import 'package:audioloca/global/full.player.dart';

final albumServices = AlbumServices();
final audioServices = AudioServices();
final playerService = LocalPlayerService();

class AlbumScreen extends StatefulWidget {
  final String jwtToken;
  final int albumId;

  const AlbumScreen({super.key, required this.jwtToken, required this.albumId});

  @override
  State<AlbumScreen> createState() => AlbumScreenState();
}

class AlbumScreenState extends State<AlbumScreen> {
  Album? album;
  List<Audio> audios = [];

  @override
  void initState() {
    super.initState();
    fetchAlbumAndAudios();
  }

  Future<void> fetchAlbumAndAudios() async {
    final fetchedAlbum = await albumServices.readSpecificAlbum(
      widget.jwtToken,
      widget.albumId,
    );

    final fetchedAudios = await audioServices.readAudioAlbum(
      widget.jwtToken,
      widget.albumId,
    );

    setState(() {
      album = fetchedAlbum;
      audios = fetchedAudios;
    });
  }

  String formatDuration(String rawDuration) {
    try {
      final parts = rawDuration.split(":");
      final minutes = int.parse(parts[1]);
      final seconds = int.parse(parts[2].split("+")[0]);
      return "${minutes.toString().padLeft(2, "0")}:${seconds.toString().padLeft(2, "0")}";
    } catch (e) {
      return rawDuration;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (album == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.color1)),
      );
    }

    final albumCoverUrl =
        "${Environment.audiolocaBaseUrl}/${album!.albumCover}";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Album", style: AppTextStyles.subtitle),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: AlbumHeaderCard(
              albumCoverUrl: albumCoverUrl,
              albumName: album!.albumName,
              createdAt: album!.createdAt,
              description: album!.description,
              onEdit: () {},
              onDelete: () {},
            ),
          ),
          Expanded(
            child: audios.isEmpty
                ? const Center(
                    child: Text(
                      "No audio found.",
                      style: AppTextStyles.bodySmall,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: audios.length,
                    itemBuilder: (context, index) {
                      final audio = audios[index];
                      return AudioListItem(
                        audioPhoto: audio.albumCover,
                        title: audio.audioTitle,
                        plays: audio.streamCount,
                        duration: formatDuration(audio.duration),
                        onTap: () async {
                          final audioUrl =
                              "${Environment.audiolocaBaseUrl}/${audio.audioRecord}";
                          final photoUrl =
                              "${Environment.audiolocaBaseUrl}/${audio.albumCover}";

                          try {
                            await playerService.playFromUrl(
                              url: audioUrl,
                              title: audio.audioTitle,
                              subtitle: audio.username,
                              imageUrl: photoUrl,
                            );

                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const FullPlayerScreen(),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Failed to play audio"),
                                ),
                              );
                            }
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

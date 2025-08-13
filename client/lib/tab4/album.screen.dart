import 'package:flutter/material.dart';
import 'package:audioloca/environment.dart';
import 'package:audioloca/services/album.service.dart';
import 'package:audioloca/services/audio.service.dart';
import 'package:audioloca/services/audio.player.service.dart';
import 'package:audioloca/models/album.model.dart';
import 'package:audioloca/models/audio.model.dart';
import 'package:audioloca/tab4/tab4.widgets/album.audio.dart';
import 'package:audioloca/tab4/tab4.widgets/album.card.dart';
import 'package:audioloca/theme.dart';
import 'package:audioloca/global/full.player.dart';

final albumServices = AlbumServices();
final audioServices = AudioServices();
final playerService = AudioPlayerService();

class AlbumScreen extends StatefulWidget {
  final String jwtToken;
  final int albumId;

  const AlbumScreen({super.key, required this.jwtToken, required this.albumId});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
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

  @override
  Widget build(BuildContext context) {
    if (album == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final imageUrl = '${Environment.audiolocaBaseUrl}/${album!.albumCover}';

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
              imageUrl: imageUrl,
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
                      "No audio found",
                      style: AppTextStyles.bodySmall,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: audios.length,
                    itemBuilder: (context, index) {
                      final audio = audios[index];
                      return AudioListItem(
                        title: audio.audioTitle,
                        plays: 0, // update based on your model
                        duration: audio.duration,
                        onTap: () async {
                          final audioUrl =
                              '${Environment.audiolocaBaseUrl}/${audio.audioRecord}';
                          final photoUrl =
                              '${Environment.audiolocaBaseUrl}/${audio.audioPhoto}';

                          try {
                            await playerService.playFromUrl(
                              url: audioUrl,
                              title: audio.audioTitle,
                              subtitle: album!.albumName,
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
                                  content: Text('Failed to play audio'),
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

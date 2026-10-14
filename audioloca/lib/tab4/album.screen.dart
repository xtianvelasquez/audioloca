import 'package:flutter/material.dart';
import 'package:audioloca/theme.dart';
import 'package:audioloca/environment.dart';
import 'package:audioloca/core/utils.dart';
import 'package:audioloca/core/alert.dialog.dart';
import 'package:audioloca/player/controllers/local.player.dart';
import 'package:audioloca/player/views/full.player.dart';
import 'package:audioloca/local/services/album.service.dart';
import 'package:audioloca/local/services/audio.service.dart';
import 'package:audioloca/local/models/album.model.dart';
import 'package:audioloca/local/models/audio.model.dart';
import 'package:audioloca/view/audio.card.dart';
import 'package:audioloca/view/album.header.dart';
import 'package:audioloca/player/views/mini.player.dart';

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
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAlbumAndAudios();
  }

  Future<void> fetchAlbumAndAudios() async {
    try {
      final fetchedAlbum = await albumServices.readAlbum(
        widget.jwtToken,
        widget.albumId,
      );

      final fetchedAudios = await audioServices.readAudioAlbum(
        widget.jwtToken,
        widget.albumId,
      );

      if (!mounted) return;
      setState(() {
        album = fetchedAlbum;
        audios = fetchedAudios;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        CustomAlertDialog.failed(context, e);
      }
    }
  }

  Future<void> handleTrackTap(Audio audio) async {
    final audioUrl = "${Environment.audiolocaBaseUrl}/${audio.audioRecord}";
    final photoUrl = "${Environment.audiolocaBaseUrl}/${audio.albumCover}";

    try {
      await playerService.playFromUrl(
        url: audioUrl,
        title: audio.audioTitle,
        subtitle: audio.username,
        imageUrl: photoUrl,
      );

      setState(() {});

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FullPlayerScreen()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to play ${audio.audioTitle}. Please try again later.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Album Details",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.dark,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: isLoading || album == null
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryPurple,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        AlbumHeader(
                          imageUrl: resolveImageUrl(album!.albumCover),
                          title: album!.albumName,
                          subtitle: album!.createdAt,
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          "Tracks",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.dark,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (audios.isEmpty)
                          ClayCard(
                            radius: 20,
                            padding: const EdgeInsets.all(24),
                            child: const Center(
                              child: Text(
                                "No audio found in this album.",
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        else
                          ...audios.map(
                            (audio) => AudioListItem(
                              imageUrl: resolveImageUrl(audio.albumCover),
                              title: audio.audioTitle,
                              subtitle: audio.username,
                              streamCount: audio.streamCount,
                              duration: formatLocalTrackDuration(
                                audio.duration,
                              ),
                              onTap: () => handleTrackTap(audio),
                            ),
                          ),
                        const SizedBox(height: 80),
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

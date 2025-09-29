import 'package:flutter/material.dart';
import 'package:audioloca/theme.dart';
import 'package:audioloca/environment.dart';
import 'package:audioloca/core/utils.dart';
import 'package:audioloca/core/alert.dialog.dart';
import 'package:audioloca/player/controllers/local.player.dart';
import 'package:audioloca/player/views/full.player.dart';
import 'package:audioloca/local/controllers/album.service.dart';
import 'package:audioloca/local/controllers/audio.service.dart';
import 'package:audioloca/local/models/album.model.dart';
import 'package:audioloca/local/models/audio.model.dart';
import 'package:audioloca/view/audio.card.dart';
import 'package:audioloca/view/album.header.dart';

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
      });
    } catch (e) {
      if (mounted) {
        CustomAlertDialog.failed(
          context,
          "Failed to fetch album or audio list.",
        );
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
    if (album == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.color1)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Album", style: AppTextStyles.subtitle),
        backgroundColor: AppColors.color1,
        foregroundColor: AppColors.light,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: AlbumHeader(
              imageUrl: resolveImageUrl(album!.albumCover),
              title: album!.albumName,
              subtitle: album!.createdAt,
              showActions: true,
              onEdit: () {},
              onDelete: () {},
            ),
          ),
          Expanded(
            child: audios.isEmpty
                ? const Center(
                    child: Text(
                      "No audio found.",
                      style: AppTextStyles.keyword,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: audios.length,
                    itemBuilder: (context, index) {
                      final audio = audios[index];
                      return AudioListItem(
                        imageUrl: resolveImageUrl(audio.albumCover),
                        title: audio.audioTitle,
                        subtitle: audio.username,
                        streamCount: audio.streamCount,
                        duration: formatLocalTrackDuration(audio.duration),
                        onTap: () => handleTrackTap(audio),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

import 'package:logger/logger.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:audioloca/theme.dart';
import 'package:audioloca/environment.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/core/alert.dialog.dart';
import 'package:audioloca/local/services/album.service.dart';
import 'package:audioloca/local/models/album.model.dart';
import 'package:audioloca/tab4/tab4.forms/album.form.dart';
import 'package:audioloca/tab4/tab4.forms/audio.form.dart';
import 'package:audioloca/tab4/album.screen.dart';
import 'package:audioloca/login/login.page.dart';
import 'package:audioloca/player/views/mini.player.dart';
import 'package:audioloca/tabs/tabs.routing.dart';

final log = Logger();
final storage = SecureStorageService();
final albumServices = AlbumServices();

class Tab4 extends StatefulWidget {
  const Tab4({super.key});
  @override
  State<Tab4> createState() => Tab4State();
}

class Tab4State extends State<Tab4> {
  String? jwtToken;
  List<Album> albums = [];
  bool isLoading = true;
  int _activeCategory = 0;

  @override
  void initState() {
    super.initState();
    loadAlbums();
  }

  Future<void> loadAlbums() async {
    setState(() {
      isLoading = true;
    });

    final token = await storage.getJwtToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      CustomAlertDialog.failed(
        context,
        "Authentication required. Please log in.",
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
      return;
    }

    setState(() {
      jwtToken = token;
    });

    try {
      final data = await albumServices.readAlbums(token);
      if (!mounted) return;
      setState(() {
        albums = data;
        isLoading = false;
      });
    } catch (e, stackTrace) {
      log.d("[Flutter] Error fetching albums: $e $stackTrace");
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> openFormDialog({
    required String title,
    required Widget form,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          elevation: 16,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.dark,
            ),
          ),
          content: SingleChildScrollView(
            child: SizedBox(width: 400, child: form),
          ),
        );
      },
    );
    loadAlbums();
  }

  Future<void> handleDeleteAlbumTap({
    required BuildContext context,
    required String jwtToken,
    required Album album,
    required VoidCallback onSuccess,
  }) async {
    final confirmed = await CustomAlertDialog.confirmAction(
      context: context,
      title: 'Delete Album',
      message:
          'Are you sure you want to delete the album "${album.albumName}"? This action cannot be undone.',
    );

    if (!confirmed) return;

    try {
      await albumServices.deleteSpecificAlbum(jwtToken, album.albumId);
      if (context.mounted) {
        CustomAlertDialog.success(context, 'Album deleted successfully.');
        onSuccess();
      }
    } catch (e) {
      if (context.mounted) {
        CustomAlertDialog.failed(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMid,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header with AudioLoca title and floating 3D note (matching Screen 8)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "AudioLoca",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.dark,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFFBA9EF9), Color(0xFF6F43CC)],
                        center: Alignment(-0.3, -0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryPurple.withValues(alpha: 0.3),
                          offset: const Offset(1, 4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.music_note_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Segmented Pills [All] [Emotion] [Location] (matching Screen 6 & 8)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5DCF8),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowDark.withValues(alpha: 0.12),
                      offset: const Offset(1, 3),
                      blurRadius: 6,
                    ),
                    const BoxShadow(
                      color: Colors.white,
                      offset: Offset(-1, -1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _buildPillItem(0, "All"),
                    _buildPillItem(1, "Emotion"),
                    _buildPillItem(2, "Location"),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Section: "Your Audio"
              const Text(
                "Your Audio",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 12),

              // Two Big Action Buttons (matching Reference design Screen 6 & 8)
              Row(
                children: [
                  Expanded(
                    child: ClayButton(
                      text: "Add Album",
                      icon: Icons.add_box_rounded,
                      radius: 20,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      onPressed: () => openFormDialog(
                        title: "Create New Album",
                        form: const AlbumInputForm(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClayButton(
                      text: "Add Audio",
                      icon: Icons.music_note_rounded,
                      radius: 20,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      onPressed: () => openFormDialog(
                        title: "Upload New Audio",
                        form: const AudioInputForm(),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Section: "Your Albums"
              const Text(
                "Your Albums",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 12),

              // Albums List (matching Screen 6 & 8)
              if (isLoading)
                const SizedBox(
                  height: 180,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryPurple,
                    ),
                  ),
                )
              else if (albums.isEmpty)
                ClayCard(
                  radius: 20,
                  padding: const EdgeInsets.all(28),
                  child: Center(
                    child: Column(
                      children: const [
                        Icon(
                          Icons.album_rounded,
                          size: 44,
                          color: AppColors.color2,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'No albums found.\nTap "+ Add Album" to create one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: albums.length,
                  itemBuilder: (context, index) {
                    final album = albums[index];
                    final imageUrl =
                        "${Environment.audiolocaBaseUrl}/${album.albumCover}";

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AlbumScreen(
                                jwtToken: jwtToken!,
                                albumId: album.albumId,
                              ),
                            ),
                          );
                        },
                        onLongPress: () {
                          handleDeleteAlbumTap(
                            context: context,
                            jwtToken: jwtToken!,
                            album: album,
                            onSuccess: () {
                              loadAlbums();
                            },
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: ClayDecorations.card(radius: 20),
                          child: Row(
                            children: [
                              // Album Cover
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  imageUrl: imageUrl,
                                  placeholder: (_, __) => Container(
                                    width: 52,
                                    height: 52,
                                    color: AppColors.pillBg,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: AppColors.primaryPurple,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    width: 52,
                                    height: 52,
                                    color: AppColors.pillBg,
                                    child: const Icon(
                                      Icons.album_rounded,
                                      size: 28,
                                      color: AppColors.color2,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Album Name & details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      album.albumName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppColors.dark,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      "Album • ${album.createdAt.toString().split(' ').first}",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Chevron Right
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.pillBg.withValues(
                                    alpha: 0.5,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.primaryPurple,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  Widget _buildPillItem(int index, String label) {
    final isSelected = _activeCategory == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _activeCategory = index);
          if (index == 0) {
            // All stays on tab 4 or switches
          } else if (index == 1) {
            TabsRouting.of(context)?.setTab(0);
          } else if (index == 2) {
            TabsRouting.of(context)?.setTab(0);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: isSelected
              ? BoxDecoration(
                  gradient: AppGradients.primaryButton,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPurple.withValues(alpha: 0.35),
                      offset: const Offset(1, 3),
                      blurRadius: 8,
                    ),
                  ],
                )
              : const BoxDecoration(),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.primaryPurple,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

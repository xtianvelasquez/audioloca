import 'package:logger/logger.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:audioloca/theme.dart';
import 'package:audioloca/environment.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/core/alert.dialog.dart';
import 'package:audioloca/local/controllers/album.service.dart';
import 'package:audioloca/local/models/album.model.dart';
import 'package:audioloca/tab4/tab4.forms/album.form.dart';
import 'package:audioloca/tab4/tab4.forms/audio.form.dart';
import 'package:audioloca/tab4/album.screen.dart';
import 'package:audioloca/login/login.page.dart';
import 'package:audioloca/player/views/mini.player.dart';

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

  @override
  void initState() {
    super.initState();
    loadAlbums();
  }

  Future<void> loadAlbums() async {
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
      setState(() {
        albums = data;
        isLoading = false;
      });
    } catch (e, stackTrace) {
      log.d("[Flutter] Error fetching albums: $e $stackTrace");
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
          backgroundColor: AppColors.light,
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(title),
          content: SingleChildScrollView(
            child: SizedBox(width: 400, child: form),
          ),
        );
      },
    );
    loadAlbums();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("AudioLoca"),
        backgroundColor: AppColors.color1,
        foregroundColor: AppColors.light,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.library_add),
                      label: const Text("Add Album"),
                      onPressed: () => openFormDialog(
                        title: "Create New Album",
                        form: const AlbumInputForm(),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.color1,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.music_note),
                      label: const Text("Add Audio"),
                      onPressed: () => openFormDialog(
                        title: "Upload New Audio",
                        form: const AudioInputForm(),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.color1,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Albums header
              const Text(
                "Your Albums",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Album Grid
              if (isLoading)
                const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (albums.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No albums found. Tap "Add Album" to create one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: albums.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemBuilder: (context, index) {
                    final album = albums[index];
                    final imageUrl =
                        "${Environment.audiolocaBaseUrl}/${album.albumCover}";

                    return InkWell(
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
                      borderRadius: BorderRadius.circular(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              height: 100,
                              width: 100,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                height: 100,
                                width: 100,
                                color: Colors.grey[300],
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                height: 100,
                                width: 100,
                                color: Colors.grey[300],
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            album.albumName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

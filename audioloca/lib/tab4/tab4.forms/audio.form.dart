import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import 'package:flutter/material.dart';

import 'package:audioloca/theme.dart';
import 'package:audioloca/core/alert.dialog.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/local/services/genre.service.dart';
import 'package:audioloca/local/services/album.service.dart';
import 'package:audioloca/local/services/audio.service.dart';
import 'package:audioloca/local/models/genres.model.dart';
import 'package:audioloca/local/models/album.model.dart';
import 'package:audioloca/login/login.page.dart';

final log = Logger();
final storage = SecureStorageService();
final audioServices = AudioServices();

class AudioInputForm extends StatefulWidget {
  const AudioInputForm({super.key});

  @override
  AudioInputFormState createState() => AudioInputFormState();
}

class AudioInputFormState extends State<AudioInputForm> {
  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();

  List<Genres> genres = [];
  List<Album> albums = [];

  int? albumValue;
  int? genreValue;
  String? visibilityValue;

  FilePickerResult? audio;
  AudioPlayer? previewPlayer;
  bool isPlayingPreview = false;

  @override
  void initState() {
    super.initState();
    loadGenres();
    loadAlbums();
  }

  @override
  void dispose() {
    previewPlayer?.dispose();
    titleController.dispose();
    super.dispose();
  }

  Future<void> loadGenres() async {
    try {
      final data = await GenreServices().readGenres();
      if (mounted) setState(() => genres = data);
    } catch (e, stackTrace) {
      log.e("[Flutter] Error fetching genres: $e $stackTrace");
    }
  }

  Future<void> loadAlbums() async {
    final jwtToken = await storage.getJwtToken();
    if (jwtToken == null || jwtToken.isEmpty) {
      if (!mounted) return;
      CustomAlertDialog.failed(
        context,
        "Authentication required. Please log in.",
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      return;
    }

    try {
      final data = await AlbumServices().readAlbums(jwtToken);
      if (mounted) setState(() => albums = data);
    } catch (e, stackTrace) {
      log.e("[Flutter] Error fetching albums: $e $stackTrace");
    }
  }

  bool validateSelections() {
    if (albumValue == null || genreValue == null || visibilityValue == null) {
      CustomAlertDialog.failed(context, "Please fill all dropdown selections.");
      return false;
    }
    if (audio == null) {
      CustomAlertDialog.failed(context, "Please select an audio file.");
      return false;
    }
    return true;
  }

  Future<void> handleSubmit() async {
    if (!formKey.currentState!.validate()) return;
    if (!validateSelections()) return;

    try {
      final audioFile = File(audio!.files.first.path!);
      final audioFileSizeInMB = (await audioFile.length()) / (1024 * 1024);

      if (audioFileSizeInMB > 15) {
        if (!mounted) return;
        CustomAlertDialog.failed(context, "Audio file size is too big.");
        return;
      }

      final player = AudioPlayer();
      await player.setFilePath(audioFile.path);
      final audioDuration = player.duration;
      await player.dispose();

      if (audioDuration == null) {
        if (!mounted) return;
        CustomAlertDialog.failed(
          context,
          "Audio duration is unknown. Please try again.",
        );
        return;
      }

      if (audioDuration.inSeconds > 600) {
        if (!mounted) return;
        CustomAlertDialog.failed(
          context,
          "Audio duration is too long. Please try again.",
        );
        return;
      }

      final jwtToken = await storage.getJwtToken();
      if (jwtToken == null || jwtToken.isEmpty) {
        if (!mounted) return;
        CustomAlertDialog.failed(
          context,
          "Authentication required. Please log in.",
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
        return;
      }

      final response = await audioServices.createAudio(
        albumID: albumValue!,
        genreID: genreValue!,
        visibility: visibilityValue!,
        audioTitle: titleController.text.trim(),
        duration: audioDuration.toString().split(".").first,
        audioRecord: audioFile,
        jwtToken: jwtToken,
      );

      if (!mounted) return;

      if (response) {
        CustomAlertDialog.success(
          context,
          "Audio has been successfully stored.",
        );
        titleController.clear();
        await previewPlayer?.stop();
        if (mounted) {
          setState(() {
            audio = null;
            albumValue = null;
            genreValue = null;
            visibilityValue = null;
            isPlayingPreview = false;
          });
          Navigator.of(context).pop();
        }
      } else {
        CustomAlertDialog.failed(
          context,
          "Failed to store audio. Please try again later.",
        );
      }
    } catch (e, stackTrace) {
      log.e("[Flutter] Error in handleSubmit: $e $stackTrace");
      if (!mounted) return;
      CustomAlertDialog.failed(
        context,
        "An unexpected error occurred. Please try again later.",
      );
    }
  }

  Future<void> pickAudio() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ["mp3", "aac", "wav", "x-wav"],
      );

      if (picked != null) {
        await previewPlayer?.dispose();
        previewPlayer = AudioPlayer();
        await previewPlayer!.setFilePath(picked.files.first.path!);

        setState(() {
          audio = picked;
          isPlayingPreview = false;
        });
      }
    } catch (e, stackTrace) {
      log.e("[Flutter] Audio pick error: $e $stackTrace");
      if (!mounted) return;
      CustomAlertDialog.failed(
        context,
        "Failed to pick audio file. Please try again.",
      );
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      filled: true,
      fillColor: AppColors.pillBg.withValues(alpha: 0.45),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty || genres.isEmpty) {
      return const SizedBox(
        height: 150,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );
    }

    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<int>(
            initialValue: albumValue,
            decoration: _inputDecoration("Select Album"),
            items: albums
                .map(
                  (album) => DropdownMenuItem(
                    value: album.albumId,
                    child: Text(
                      album.albumName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.dark,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) => setState(() => albumValue = val),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<int>(
            initialValue: genreValue,
            decoration: _inputDecoration("Select Genre"),
            items: genres
                .map(
                  (genre) => DropdownMenuItem(
                    value: genre.genreId,
                    child: Text(
                      genre.genreName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.dark,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) => setState(() => genreValue = val),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            initialValue: visibilityValue,
            decoration: _inputDecoration("Select Visibility"),
            items: const ["public", "private"]
                .map(
                  (val) => DropdownMenuItem(
                    value: val,
                    child: Text(
                      val,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.dark,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) => setState(() => visibilityValue = val),
          ),
          const SizedBox(height: 14),

          // Pick Audio Button / Box
          GestureDetector(
            onTap: pickAudio,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.pillBg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.primaryPurple.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    audio != null
                        ? Icons.audio_file_rounded
                        : Icons.upload_file_rounded,
                    color: AppColors.primaryPurple,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    audio != null
                        ? audio!.files.first.name
                        : "Select Audio File",
                    style: const TextStyle(
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),

          if (audio != null) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClayCircleButton(
                  icon: isPlayingPreview
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 36,
                  onPressed: () async {
                    if (previewPlayer == null) return;
                    if (isPlayingPreview) {
                      await previewPlayer!.pause();
                    } else {
                      await previewPlayer!.play();
                    }
                    if (mounted) {
                      setState(() => isPlayingPreview = !isPlayingPreview);
                    }
                  },
                ),
                const SizedBox(width: 10),
                const Text(
                  "Preview Audio",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dark,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),

          TextFormField(
            controller: titleController,
            maxLength: 50,
            style: const TextStyle(
              color: AppColors.dark,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            decoration: _inputDecoration("Audio Title"),
            validator: (value) => value == null || value.trim().isEmpty
                ? "Title is required"
                : null,
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: 10),
              ClayButton(
                text: "Upload Audio",
                icon: Icons.check_rounded,
                radius: 20,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                onPressed: handleSubmit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

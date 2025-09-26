import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import 'package:flutter/material.dart';

import 'package:audioloca/core/alert.dialog.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/local/controllers/genre.service.dart';
import 'package:audioloca/local/controllers/album.service.dart';
import 'package:audioloca/local/controllers/audio.service.dart';
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
      log.e("[Flutter] Error fetching genres: $e", stackTrace: stackTrace);
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
      log.e("[Flutter] Error fetching albums: $e", stackTrace: stackTrace);
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
        CustomAlertDialog.failed(
          context,
          "Audio file size is too big. Please try again!",
        );
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
          "Audio duration is unknown. Please try again!",
        );
        return;
      }

      if (audioDuration.inSeconds > 600) {
        if (!mounted) return;
        CustomAlertDialog.failed(
          context,
          "Audio duration is too long. Please try again!",
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
        setState(() {
          audio = null;
          albumValue = null;
          genreValue = null;
          visibilityValue = null;
          isPlayingPreview = false;
        });
      } else {
        CustomAlertDialog.failed(
          context,
          "Failed to store audio. Please try again!",
        );
      }
    } catch (e, stackTrace) {
      log.e("Error in handleSubmit: $e", stackTrace: stackTrace);
      if (!mounted) return;
      CustomAlertDialog.failed(context, "An unexpected error occurred.");
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
      log.e("[Flutter] Audio pick error: $e", stackTrace: stackTrace);
      if (!mounted) return;
      CustomAlertDialog.failed(context, "Failed to pick audio file.");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty || genres.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            initialValue: albumValue,
            decoration: const InputDecoration(labelText: "Select Album"),
            items: albums
                .map(
                  (album) => DropdownMenuItem(
                    value: album.albumId,
                    child: Text(album.albumName),
                  ),
                )
                .toList(),
            onChanged: (val) => setState(() => albumValue = val),
          ),
          DropdownButtonFormField<int>(
            initialValue: genreValue,
            decoration: const InputDecoration(labelText: "Select Genre"),
            items: genres
                .map(
                  (genre) => DropdownMenuItem(
                    value: genre.genreId,
                    child: Text(genre.genreName),
                  ),
                )
                .toList(),
            onChanged: (val) => setState(() => genreValue = val),
          ),
          DropdownButtonFormField<String>(
            initialValue: visibilityValue,
            decoration: const InputDecoration(labelText: "Select Visibility"),
            items: const ["public", "private"]
                .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                .toList(),
            onChanged: (val) => setState(() => visibilityValue = val),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: pickAudio,
            child: const Text("Select Audio File"),
          ),
          if (audio != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      isPlayingPreview ? Icons.pause : Icons.play_arrow,
                    ),
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
                  const Text("Preview Audio"),
                ],
              ),
            ),
          TextFormField(
            controller: titleController,
            maxLength: 50,
            decoration: const InputDecoration(labelText: "Audio Title"),
            validator: (value) => value == null || value.trim().isEmpty
                ? "Title is required"
                : null,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Cancel"),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: handleSubmit,
                child: const Text("Submit"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

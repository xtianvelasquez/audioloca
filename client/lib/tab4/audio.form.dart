import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import 'package:audioloca/global/alert.dialog.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/services/genres.service.dart';
import 'package:audioloca/services/album.service.dart';
import 'package:audioloca/services/audio.service.dart';
import 'package:audioloca/models/genres.model.dart';
import 'package:audioloca/models/album.model.dart';
import 'package:audioloca/login/login.page.dart';
import 'package:audioloca/theme.dart';

final log = Logger();
final storage = SecureStorageService();
final audioServices = AudioServices();

class AudioInputForm extends StatefulWidget {
  const AudioInputForm({super.key});
  @override
  AudioInputFormState createState() => AudioInputFormState();
}

class AudioInputFormState extends State<AudioInputForm> {
  List<Genres> genres = [];
  List<Album> albums = [];

  final formKey = GlobalKey<FormState>();
  int? albumValue;
  int? genreValue;
  String? visibilityValue;

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();

  FilePickerResult? audio;
  AudioPlayer? previewPlayer;
  bool isPlayingPreview = false;

  @override
  void initState() {
    super.initState();
    loadGenres();
    loadAlbums();
  }

  Future<void> loadGenres() async {
    try {
      final data = await GenreServices().readGenres();
      setState(() => genres = data);
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
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
      return;
    }

    try {
      final data = await AlbumServices().readAlbums(jwtToken);
      setState(() => albums = data);
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
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
      return;
    }

    final response = await audioServices.createAudio(
      albumID: albumValue!,
      genreID: genreValue!,
      visibility: visibilityValue!,
      audioTitle: titleController.text.trim(),
      description: descriptionController.text.trim(),
      duration: audioDuration.toString().split(".").first,
      audioRecord: audioFile,
      jwtToken: jwtToken,
    );

    if (response) {
      if (!mounted) return;
      CustomAlertDialog.success(context, "Audio has been successfully stored.");
      titleController.clear();
      descriptionController.clear();
      previewPlayer?.stop();
      setState(() {
        audio = null;
        albumValue = null;
        genreValue = null;
        visibilityValue = null;
        isPlayingPreview = false;
      });
    } else {
      if (!mounted) return;
      CustomAlertDialog.failed(
        context,
        "Failed to store audio. Please try again!",
      );
    }
  }

  @override
  void dispose() {
    previewPlayer?.dispose();
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty || genres.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: SizedBox(
        width: 400,
        child: AlertDialog(
          backgroundColor: AppColors.light,
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            "Upload New Audio",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: albumValue,
                    items: albums
                        .map(
                          (album) => DropdownMenuItem<int>(
                            value: album.albumId,
                            child: Text(album.albumName),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => albumValue = val),
                    decoration: const InputDecoration(
                      labelText: "Select Album",
                    ),
                  ),
                  DropdownButtonFormField<int>(
                    value: genreValue,
                    items: genres
                        .map(
                          (genre) => DropdownMenuItem<int>(
                            value: genre.genreId,
                            child: Text(genre.genreName),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => genreValue = val),
                    decoration: const InputDecoration(
                      labelText: "Select Genre",
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    value: visibilityValue,
                    items: ["public", "private"]
                        .map(
                          (val) =>
                              DropdownMenuItem(value: val, child: Text(val)),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => visibilityValue = val),
                    decoration: const InputDecoration(
                      labelText: "Select Visibility",
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final picked = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ["mp3", "aac", "wav", "x-wav"],
                        );
                        if (picked != null) {
                          previewPlayer?.dispose();
                          previewPlayer = AudioPlayer();
                          await previewPlayer!.setFilePath(
                            picked.files.first.path!,
                          );
                          setState(() {
                            audio = picked;
                            isPlayingPreview = false;
                          });
                        }
                      } catch (e) {
                        log.d("[Flutter] Audio pick error: $e");
                      }
                    },
                    child: const Text("Select Audio File"),
                  ),
                  if (audio != null)
                    Row(
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
                            setState(
                              () => isPlayingPreview = !isPlayingPreview,
                            );
                          },
                        ),
                        const Text("Preview Audio"),
                      ],
                    ),
                  TextFormField(
                    controller: titleController,
                    maxLength: 50,
                    decoration: const InputDecoration(labelText: "Audio Title"),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? "Title is required"
                        : null,
                  ),
                  TextFormField(
                    controller: descriptionController,
                    maxLines: null,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: "About the Audio",
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? "Description is required."
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(onPressed: handleSubmit, child: const Text("Submit")),
          ],
        ),
      ),
    );
  }
}

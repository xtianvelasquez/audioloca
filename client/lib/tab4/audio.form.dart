import 'dart:io';
import 'package:logger/logger.dart';
import 'package:just_audio/just_audio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/services/emotions.service.dart';
import 'package:audioloca/services/album.service.dart';
import 'package:audioloca/services/audio.service.dart';
import 'package:audioloca/models/emotions.model.dart';
import 'package:audioloca/models/album.model.dart';
import 'package:audioloca/models/audio.model.dart';
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
  List<AudioType> audioTypes = [];
  List<Emotions> emotions = [];
  List<Album> albums = [];

  final formKey = GlobalKey<FormState>();

  int? audioTypeValue;
  int? albumValue;
  int? emotionValue;
  String? visibilityValue;

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();

  XFile? image;
  FilePickerResult? audio;
  AudioPlayer? previewPlayer;
  bool isPlayingPreview = false;

  @override
  void initState() {
    super.initState();
    loadAudioType();
    loadEmotions();
    loadAlbums();
  }

  Future<void> loadEmotions() async {
    try {
      final data = await EmotionServices().readEmotions();
      setState(() => emotions = data);
    } catch (e, stackTrace) {
      log.e('[Flutter] Error fetching emotions: $e $stackTrace');
    }
  }

  Future<void> loadAudioType() async {
    try {
      final data = await AudioServices().readAudioType();
      setState(() => audioTypes = data);
    } catch (e, stackTrace) {
      log.e('[Flutter] Error fetching audio type: $e $stackTrace');
    }
  }

  Future<void> loadAlbums() async {
    final jwtToken = await storage.getJwtToken();
    if (jwtToken == null || jwtToken.isEmpty) {
      if (!mounted) return;
      _showSnackBar("Authentication required. Please log in.");
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
      log.e('[Flutter] Error fetching albums: $e $stackTrace');
    }
  }

  void _showSnackBar(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color ?? AppColors.secondary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _validateSelections() {
    if (albumValue == null ||
        audioTypeValue == null ||
        emotionValue == null ||
        visibilityValue == null) {
      _showSnackBar("Please fill all dropdown selections.");
      return false;
    }
    if (image == null) {
      _showSnackBar("Please select an album cover.");
      return false;
    }
    if (audio == null) {
      _showSnackBar("Please select an audio file.");
      return false;
    }
    return true;
  }

  Future<void> _handleSubmit() async {
    if (!formKey.currentState!.validate()) return;
    if (!_validateSelections()) return;

    final photoFile = File(image!.path);
    final audioFile = File(audio!.files.first.path!);

    final photoFileSizeInMB = (await photoFile.length()) / (1024 * 1024);
    final audioFileSizeInMB = (await audioFile.length()) / (1024 * 1024);

    if (photoFileSizeInMB > 15) {
      _showSnackBar("Photo file size is too big. Please try again!");
      return;
    }
    if (audioFileSizeInMB > 15) {
      _showSnackBar("Audio file size is too big. Please try again!");
      return;
    }

    final player = AudioPlayer();
    await player.setFilePath(audioFile.path);
    final audioDuration = player.duration;
    if (audioDuration == null) {
      _showSnackBar("Audio duration is unknown. Please try again!");
      return;
    }
    if (audioDuration.inSeconds > 600) {
      _showSnackBar("Audio duration is too long. Please try again!");
      return;
    }

    final jwtToken = await storage.getJwtToken();
    if (jwtToken == null || jwtToken.isEmpty) {
      _showSnackBar("Authentication required. Please log in.");
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
      return;
    }

    final response = await audioServices.createAudio(
      audioTypeID: audioTypeValue!,
      albumID: albumValue!,
      emotionID: emotionValue!,
      visibility: visibilityValue!,
      audioTitle: titleController.text.trim(),
      description: descriptionController.text.trim(),
      duration: audioDuration.toString().split('.').first,
      audioPhoto: photoFile,
      audioRecord: audioFile,
      jwtToken: jwtToken,
    );

    if (response) {
      _showSnackBar("Audio has been successfully stored.", color: Colors.green);
      titleController.clear();
      descriptionController.clear();
      setState(() {
        image = null;
        audio = null;
        albumValue = null;
        emotionValue = null;
        visibilityValue = null;
      });
    } else {
      _showSnackBar("Failed to store audio. Please try again!");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty || emotions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Form(
      key: formKey,
      child: SingleChildScrollView(
        child: Column(
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
              decoration: const InputDecoration(labelText: 'Select Album'),
            ),
            DropdownButtonFormField<int>(
              value: audioTypeValue,
              items: audioTypes
                  .map(
                    (audioType) => DropdownMenuItem<int>(
                      value: audioType.audioTypeId,
                      child: Text(audioType.typeName),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() => audioTypeValue = val),
              decoration: const InputDecoration(labelText: 'Select Audio Type'),
            ),
            DropdownButtonFormField<int>(
              value: emotionValue,
              items: emotions
                  .map(
                    (emotion) => DropdownMenuItem<int>(
                      value: emotion.emotionId,
                      child: Text(emotion.emotionLabel),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() => emotionValue = val),
              decoration: const InputDecoration(labelText: 'Select Emotion'),
            ),
            DropdownButtonFormField<String>(
              value: visibilityValue,
              items: ['public', 'private']
                  .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                  .toList(),
              onChanged: (val) => setState(() => visibilityValue = val),
              decoration: const InputDecoration(labelText: 'Select Visibility'),
            ),
            ElevatedButton(
              onPressed: () async {
                final picked = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                );
                setState(() => image = picked);
              },
              child: const Text('Select Audio Photo'),
            ),
            if (image != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Image.file(File(image!.path), height: 120),
              ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final picked = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['mp3', 'aac', 'wav', 'x-wav'],
                  );
                  if (picked != null) {
                    setState(() => audio = picked);

                    previewPlayer?.dispose();
                    previewPlayer = AudioPlayer();
                    await previewPlayer!.setFilePath(picked.files.first.path!);
                  }
                } catch (e) {
                  log.d('[Flutter] Audio pick error: $e');
                }
              },
              child: const Text('Select Audio File'),
            ),
            TextFormField(
              controller: titleController,
              maxLength: 50,
              decoration: const InputDecoration(labelText: 'Audio Title'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Title is required'
                  : null,
            ),
            TextFormField(
              controller: descriptionController,
              maxLines: null,
              maxLength: 1000,
              decoration: const InputDecoration(labelText: 'About the Audio'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Description is required.'
                  : null,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _handleSubmit,
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}

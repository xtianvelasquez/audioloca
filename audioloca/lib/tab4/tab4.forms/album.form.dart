import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';

import 'package:audioloca/core/alert.dialog.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/local/controllers/album.service.dart';
import 'package:audioloca/login/login.page.dart';

final log = Logger();
final storage = SecureStorageService();
final albumServices = AlbumServices();

class AlbumInputForm extends StatefulWidget {
  const AlbumInputForm({super.key});

  @override
  State<AlbumInputForm> createState() => AlbumInputFormState();
}

class AlbumInputFormState extends State<AlbumInputForm> {
  final formKey = GlobalKey<FormState>();
  final albumNameController = TextEditingController();
  XFile? image;

  @override
  void dispose() {
    albumNameController.dispose();
    super.dispose();
  }

  Future<void> handleSubmit() async {
    if (!formKey.currentState!.validate()) return;

    if (image == null) {
      if (!mounted) return;
      CustomAlertDialog.failed(context, "Please select an album cover.");
      return;
    }

    final coverFile = File(image!.path);
    final coverFileSizeInMB = (await coverFile.length()) / (1024 * 1024);
    if (coverFileSizeInMB > 15) {
      if (!mounted) return;
      CustomAlertDialog.failed(context, "Album cover file size is too big.");
      return;
    }

    final jwtToken = await storage.getJwtToken();
    if (jwtToken == null || jwtToken.isEmpty) {
      if (!mounted) return;
      CustomAlertDialog.failed(
        context,
        "Authentication required. Please log in.",
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
      return;
    }

    try {
      final response = await albumServices.createAlbum(
        albumName: albumNameController.text.trim(),
        albumCover: coverFile,
        jwtToken: jwtToken,
      );

      if (!mounted) return;

      if (response) {
        CustomAlertDialog.success(context, "Album successfully stored.");
        albumNameController.clear();
        setState(() => image = null);
      } else {
        log.e("[Flutter] Album creation failed: $response");
        CustomAlertDialog.failed(context, "Failed to store album.");
      }
    } catch (e, stacktrace) {
      log.e("[Flutter] Error creating album: $e $stacktrace");
      if (!mounted) return;
      CustomAlertDialog.failed(
        context,
        "An unexpected error occurred. Please try again later.",
      );
    }
  }

  Future<void> selectImage() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() => image = picked);
      }
    } catch (e, stacktrace) {
      log.e("[Flutter] Image picking failed: $e $stacktrace");
      if (!mounted) return;
      CustomAlertDialog.failed(
        context,
        "Failed to pick image. Please try again.",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: selectImage,
            child: const Text("Select Album Cover"),
          ),
          if (image != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Image.file(File(image!.path), height: 120),
            ),
          TextFormField(
            controller: albumNameController,
            maxLength: 50,
            decoration: const InputDecoration(labelText: "Album Name"),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return "Album name is required";
              }
              return null;
            },
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

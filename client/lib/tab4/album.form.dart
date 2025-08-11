import 'dart:io';
import 'package:logger/logger.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/services/album.service.dart';
import 'package:audioloca/login/login.page.dart';
import 'package:audioloca/theme.dart';

final log = Logger();
final storage = SecureStorageService();
final albumServices = AlbumServices();

class AlbumInputForm extends StatefulWidget {
  const AlbumInputForm({super.key});

  @override
  AlbumInputFormState createState() => AlbumInputFormState();
}

class AlbumInputFormState extends State<AlbumInputForm> {
  final formKey = GlobalKey<FormState>();

  final albumNameController = TextEditingController();
  final descriptionController = TextEditingController();

  XFile? image;

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

  @override
  void dispose() {
    albumNameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          // Album cover selector
          ElevatedButton(
            child: const Text('Select Album Cover'),
            onPressed: () async {
              final picked = await ImagePicker().pickImage(
                source: ImageSource.gallery,
              );
              if (picked != null) {
                setState(() => image = picked);
              }
            },
          ),
          if (image != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Image.file(File(image!.path), height: 120),
            ),

          // Album name
          TextFormField(
            controller: albumNameController,
            maxLength: 50,
            decoration: const InputDecoration(labelText: 'Album Name'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Album name is required.';
              }
              return null;
            },
          ),

          // Album description
          TextFormField(
            controller: descriptionController,
            maxLines: null,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'About the Album'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Description is required.';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // Submit button
          ElevatedButton(
            child: const Text('Submit'),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              if (image == null) {
                _showSnackBar("Please select an album cover.");
                return;
              }

              final coverFile = File(image!.path);
              final coverFileSizeInMB =
                  (await coverFile.length()) / (1024 * 1024);
              if (coverFileSizeInMB > 15) {
                _showSnackBar(
                  "Album cover file size is too big. Please try again!",
                );
                return;
              }

              final jwtToken = await storage.getJwtToken();
              if (jwtToken == null || jwtToken.isEmpty) {
                _showSnackBar("Authentication required. Please log in.");
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                }
                return;
              }

              final response = await albumServices.createAlbum(
                albumName: albumNameController.text.trim(),
                description: descriptionController.text.trim(),
                albumCover: coverFile,
                jwtToken: jwtToken,
              );

              if (!mounted) return;

              if (response) {
                _showSnackBar(
                  "Album has been successfully stored.",
                  color: Colors.green,
                );

                albumNameController.clear();
                descriptionController.clear();
                setState(() => image = null);
              } else {
                _showSnackBar("Failed to store album. Please try again.");
              }
            },
          ),
        ],
      ),
    );
  }
}

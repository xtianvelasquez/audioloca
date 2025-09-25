import 'dart:io';
import 'package:logger/logger.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';

import 'package:audioloca/theme.dart';
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
  AlbumInputFormState createState() => AlbumInputFormState();
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

  @override
  Widget build(BuildContext context) {
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
            "Create New Album",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    child: const Text("Select Album Cover"),
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
                  TextFormField(
                    controller: albumNameController,
                    maxLength: 50,
                    decoration: const InputDecoration(labelText: "Album Name"),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Album name is required.";
                      }
                      return null;
                    },
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
            TextButton(
              child: const Text("Submit"),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                if (image == null) {
                  CustomAlertDialog.failed(
                    context,
                    "Please select an album cover.",
                  );
                  return;
                }

                final coverFile = File(image!.path);
                final coverFileSizeInMB =
                    (await coverFile.length()) / (1024 * 1024);
                if (coverFileSizeInMB > 15) {
                  if (context.mounted) {
                    CustomAlertDialog.failed(
                      context,
                      "Album cover file size is too big. Please try again!",
                    );
                  }
                  return;
                }

                final jwtToken = await storage.getJwtToken();
                if (jwtToken == null || jwtToken.isEmpty) {
                  if (context.mounted) {
                    CustomAlertDialog.failed(
                      context,
                      "Authentication required. Please log in.",
                    );
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    );
                  }
                  return;
                }

                final response = await albumServices.createAlbum(
                  albumName: albumNameController.text.trim(),
                  albumCover: coverFile,
                  jwtToken: jwtToken,
                );

                if (response) {
                  if (context.mounted) {
                    CustomAlertDialog.success(
                      context,
                      "Album has been successfully stored.",
                    );
                  }
                  albumNameController.clear();
                  setState(() => image = null);
                } else {
                  log.e("Album creation failed: $response");
                  if (context.mounted) {
                    CustomAlertDialog.failed(
                      context,
                      "Failed to store album. Please try again.",
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

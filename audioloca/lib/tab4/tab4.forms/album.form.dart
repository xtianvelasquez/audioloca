import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';

import 'package:audioloca/theme.dart';
import 'package:audioloca/core/alert.dialog.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/local/services/album.service.dart';
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
        Navigator.of(context).pop();
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Select Image Clay Box
          GestureDetector(
            onTap: selectImage,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: AppColors.pillBg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primaryPurple.withValues(alpha: 0.3),
                  style: BorderStyle.solid,
                  width: 1.5,
                ),
              ),
              child: image != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.file(
                        File(image!.path),
                        fit: BoxFit.cover,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.add_photo_alternate_rounded,
                          size: 40,
                          color: AppColors.primaryPurple,
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Select Album Cover",
                          style: TextStyle(
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Album Name Field
          TextFormField(
            controller: albumNameController,
            maxLength: 50,
            style: const TextStyle(
              color: AppColors.dark,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: "Album Name",
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.pillBg.withValues(alpha: 0.4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return "Album name is required";
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Actions
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
                text: "Create Album",
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

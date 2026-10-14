import 'package:flutter/material.dart';
import 'package:audioloca/theme.dart';
import 'package:audioloca/core/utils.dart';

class CustomAlertDialog {
  static void success(BuildContext context, String message, {String title = 'Success'}) {
    _showDialog(
      context: context,
      title: title,
      message: message,
      backgroundColor: Colors.white,
      titleColor: const Color(0xFF2E7D32),
      messageColor: AppColors.dark,
    );
  }

  static void failed(BuildContext context, dynamic message, {String title = 'Error'}) {
    final cleanMessage = sanitizeErrorMessage(message);
    _showDialog(
      context: context,
      title: title,
      message: cleanMessage,
      backgroundColor: Colors.white,
      titleColor: const Color(0xFFC62828),
      messageColor: AppColors.dark,
    );
  }

  static void _showDialog({
    required BuildContext context,
    required String title,
    required String message,
    required Color backgroundColor,
    required Color titleColor,
    required Color messageColor,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Center(
          child: AlertDialog(
            backgroundColor: backgroundColor,
            elevation: 16,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              title,
              style: TextStyle(
                color: titleColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            content: Text(
              message,
              style: TextStyle(
                color: messageColor,
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ClayButton(
                text: 'OK',
                radius: 20,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 10,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<bool> confirmAction({
    required BuildContext context,
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Center(
          child: AlertDialog(
            backgroundColor: Colors.white,
            elevation: 16,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: AppColors.dark,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            content: Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ClayButton(
                text: 'Confirm',
                radius: 20,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        );
      },
    );

    return result ?? false;
  }
}

import 'package:flutter/material.dart';
import 'package:audioloca/theme.dart';

class CustomAlertDialog {
  static void success(BuildContext context, String message) {
    _showDialog(
      context: context,
      title: 'Success',
      message: message,
      backgroundColor: AppColors.light,
      titleColor: Colors.green.shade800,
      messageColor: AppColors.color1,
    );
  }

  static void failed(BuildContext context, String message) {
    _showDialog(
      context: context,
      title: 'Failed',
      message: message,
      backgroundColor: AppColors.light,
      titleColor: Colors.red.shade800,
      messageColor: AppColors.color1,
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
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(
              title,
              style: TextStyle(
                color: titleColor,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),
            content: Text(
              message,
              style: TextStyle(color: messageColor, fontSize: 16),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }
}

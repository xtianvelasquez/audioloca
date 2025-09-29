import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:audioloca/theme.dart';

class UserHeader extends StatelessWidget {
  final String title;
  final DateTime subtitle;
  final VoidCallback? onLogout;
  final bool showActions;

  const UserHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.onLogout,
    this.showActions = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: AppColors.color3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/audioloca.png',
                    height: 50,
                    width: 50,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.subtitle),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat("MM/dd/yyyy").format(subtitle),
                        style: AppTextStyles.keyword,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (showActions) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: onLogout, child: const Text("LOGOUT")),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

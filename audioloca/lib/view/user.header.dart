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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ClayDecorations.card(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowDark.withValues(alpha: 0.15),
                      offset: const Offset(1, 3),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/audioloca.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Joined: ${DateFormat('MM/dd/yyyy').format(subtitle)}",
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showActions) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ClayButton(
                  text: "LOGOUT",
                  icon: Icons.logout_rounded,
                  isSecondary: true,
                  radius: 20,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  onPressed: onLogout,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

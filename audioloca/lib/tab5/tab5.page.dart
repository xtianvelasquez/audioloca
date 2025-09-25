import 'package:flutter/material.dart';
import 'package:audioloca/theme.dart';
import 'package:audioloca/core/alert.dialog.dart';
import 'package:audioloca/local/controllers/user.service.dart';
import 'package:audioloca/local/models/user.model.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/tabs/tabs.routing.dart';
import 'package:audioloca/player/views/mini.player.dart';
import 'package:audioloca/tab5/tab5.widgets/user.card.dart';

final storage = SecureStorageService();

class Tab5 extends StatefulWidget {
  const Tab5({super.key});
  @override
  State<Tab5> createState() => Tab5tate();
}

class Tab5tate extends State<Tab5> {
  User? user;

  @override
  void initState() {
    super.initState();
    fetchUser();
  }

  Future<void> fetchUser() async {
    final fetcedhUser = await UserServices().fetchUserProfile();

    setState(() {
      user = fetcedhUser;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Album", style: AppTextStyles.subtitle),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: UserHeaderCard(
              username: user!.username,
              joinedAt: user!.joinedAt,
              onLogout: () async {
                final success = await UserServices().logout();

                if (success) {
                  setState(() {
                    user = null;
                  });

                  storage.clearAll();
                  if (context.mounted) {
                    CustomAlertDialog.success(context, 'Login successful!');

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const TabsRouting()),
                    );
                  }
                } else {
                  log.e('[Flutter] Logout failed');
                  if (context.mounted) {
                    CustomAlertDialog.success(
                      context,
                      'Logout failed. Please try again later.',
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

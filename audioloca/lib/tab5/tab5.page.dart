import 'package:flutter/material.dart';
import 'package:audioloca/theme.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/core/alert.dialog.dart';
import 'package:audioloca/local/controllers/user.service.dart';
import 'package:audioloca/local/models/user.model.dart';
import 'package:audioloca/tabs/tabs.routing.dart';
import 'package:audioloca/tab5/tab5.widgets/user.card.dart';
import 'package:audioloca/player/views/mini.player.dart';

final storage = SecureStorageService();
final userServices = UserServices();

class Tab5 extends StatelessWidget {
  const Tab5({super.key});

  Future<User?> fetchUser() async {
    return await userServices.fetchUserProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("AudioLoca"),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
        elevation: 0,
      ),
      body: FutureBuilder<User?>(
        future: fetchUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('No user data found.'));
          }

          final user = snapshot.data!;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: UserHeaderCard(
                  username: user.username,
                  joinedAt: user.joinedAt,
                  onLogout: () async {
                    final success = await userServices.logout();

                    if (success) {
                      storage.clearAll();
                      if (context.mounted) {
                        CustomAlertDialog.success(
                          context,
                          'Logout successful!',
                        );
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TabsRouting(),
                          ),
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
          );
        },
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

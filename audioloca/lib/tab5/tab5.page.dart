import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:audioloca/theme.dart';
import 'package:audioloca/environment.dart';
import 'package:audioloca/core/utils.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/core/alert.dialog.dart';
import 'package:audioloca/business/location.services.dart';
import 'package:audioloca/local/services/user.service.dart';
import 'package:audioloca/local/services/audio.service.dart';
import 'package:audioloca/local/models/user.model.dart';
import 'package:audioloca/local/models/audio.model.dart';
import 'package:audioloca/view/user.header.dart';
import 'package:audioloca/view/audio.card.dart';
import 'package:audioloca/player/player.manager.dart';
import 'package:audioloca/tabs/tabs.routing.dart';
import 'package:audioloca/login/login.page.dart';
import 'package:audioloca/player/controllers/local.player.dart';
import 'package:audioloca/player/views/full.player.dart';
import 'package:audioloca/player/views/mini.player.dart';

final log = Logger();
final storage = SecureStorageService();
final locationServices = LocationServices();
final userServices = UserServices();
final audioServices = AudioServices();
final playerService = LocalPlayerService();

class Tab5 extends StatefulWidget {
  const Tab5({super.key});
  @override
  State<Tab5> createState() => Tab5State();
}

class Tab5State extends State<Tab5> {
  String? jwtToken;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    jwtToken = await storage.getJwtToken();
    if (jwtToken == null || jwtToken!.isEmpty) {
      if (!mounted) return;
      CustomAlertDialog.failed(
        context,
        "Authentication required. Please log in.",
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TabsRouting()),
      );
    }
    setState(() {});
  }

  Future<User?> fetchUser() => userServices.fetchUserProfile();

  Future<List<Audio>> fetchLatestStreams() =>
      audioServices.readLatestStreams(jwtToken!);

  Future<void> handleLogoutTap(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final success = await userServices.logout();

    if (success) {
      locationServices.stopRealtimeTracking();
      LocationServices.disposeInstance();
      NowPlayingManager().clear();

      await storage.clearAll();

      if (context.mounted) {
        Navigator.of(context).pop();
        CustomAlertDialog.success(context, 'Logout successful!');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    } else {
      log.e('[Flutter] Logout failed');
      if (context.mounted) {
        Navigator.of(context).pop();
        CustomAlertDialog.failed(
          context,
          'Logout failed. Please try again later.',
        );
      }
    }
  }

  Future<void> handleTrackTap(Audio audio) async {
    final audioUrl = "${Environment.audiolocaBaseUrl}/${audio.audioRecord}";
    final photoUrl = "${Environment.audiolocaBaseUrl}/${audio.albumCover}";

    await playerService.playFromUrl(
      url: audioUrl,
      title: audio.audioTitle,
      subtitle: audio.username,
      imageUrl: photoUrl,
    );

    setState(() {});

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FullPlayerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (jwtToken == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("AudioLoca"),
        backgroundColor: AppColors.color1,
      ),
      body: FutureBuilder<User?>(
        future: fetchUser(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = userSnapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  UserHeader(
                    title: user.username,
                    subtitle: user.joinedAt,
                    showActions: true,
                    onLogout: () => handleLogoutTap(context),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      "Recently Played",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  FutureBuilder<List<Audio>>(
                    future: fetchLatestStreams(),
                    builder: (context, streamsSnapshot) {
                      if (!streamsSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final streams = streamsSnapshot.data!;
                      if (streams.isEmpty) {
                        return const Center(
                          child: Text("No recently played audio yet."),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: streams.length,
                        itemBuilder: (context, index) {
                          final audio = streams[index];
                          return AudioListItem(
                            imageUrl: resolveImageUrl(audio.albumCover),
                            title: audio.audioTitle,
                            subtitle: audio.username,
                            duration: formatLocalTrackDuration(audio.duration),
                            onTap: () => handleTrackTap(audio),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

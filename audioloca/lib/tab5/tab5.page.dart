import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  Future<void> handleLogoutTap() async {
    final confirmed = await CustomAlertDialog.confirmAction(
      context: context,
      title: 'Logout',
      message: 'Are you sure you want to log out of AudioLoca?',
    );

    if (!confirmed) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryPurple),
      ),
    );

    final success = await userServices.logout();

    if (success) {
      locationServices.stopRealtimeTracking();
      LocationServices.disposeInstance();
      NowPlayingManager().clear();

      await storage.clearAll();

      if (mounted) {
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
      if (mounted) {
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
      return const Scaffold(
        backgroundColor: AppColors.bgMid,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgMid,
      body: SafeArea(
        child: FutureBuilder<User?>(
          future: fetchUser(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryPurple,
                ),
              );
            }

            final user = userSnapshot.data!;

            return RefreshIndicator(
              color: AppColors.primaryPurple,
              onRefresh: () async {
                setState(() {});
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Bar: Back & More Options
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ClayCircleButton(
                          icon: Icons.arrow_back_rounded,
                          size: 40,
                          onPressed: () {
                            TabsRouting.of(context)?.setTab(0);
                          },
                        ),
                        PopupMenuButton<String>(
                          icon: Container(
                            width: 40,
                            height: 40,
                            decoration: ClayDecorations.circle(size: 40),
                            child: const Icon(
                              Icons.more_vert_rounded,
                              size: 20,
                              color: AppColors.primaryPurple,
                            ),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          onSelected: (val) {
                            if (val == 'logout') {
                              handleLogoutTap();
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'logout',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.logout_rounded,
                                    color: Colors.redAccent,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "Logout",
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Main Profile Card matching Screen 5
                    _buildProfileHeroCard(user),

                    const SizedBox(height: 24),

                    // Recently Played Title
                    const Text(
                      "Recently Played",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Recently Played Stream List
                    FutureBuilder<List<Audio>>(
                      future: fetchLatestStreams(),
                      builder: (context, streamsSnapshot) {
                        if (!streamsSnapshot.hasData) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(
                                color: AppColors.primaryPurple,
                              ),
                            ),
                          );
                        }

                        final streams = streamsSnapshot.data!;
                        if (streams.isEmpty) {
                          return ClayCard(
                            radius: 20,
                            padding: const EdgeInsets.all(24),
                            child: const Center(
                              child: Text(
                                "No recently played audio yet.",
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
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
                              duration: formatLocalTrackDuration(
                                audio.duration,
                              ),
                              onTap: () => handleTrackTap(audio),
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  // Profile Card matching Screen 5
  Widget _buildProfileHeroCard(User user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: ClayDecorations.card(radius: 26),
      child: Column(
        children: [
          // User Avatar Image
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                color: AppColors.pillBg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Image.asset(
                'assets/images/audioloca.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.person_rounded,
                  size: 70,
                  color: AppColors.primaryPurple,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // User Name
          Text(
            user.username,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.dark,
              letterSpacing: -0.3,
            ),
          ),

          const SizedBox(height: 4),

          // Created On Date
          Text(
            "Created on ${DateFormat('MMM dd, yyyy').format(user.joinedAt)}",
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 14),

          // Audio status pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.pillBg.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.music_note_rounded,
                  size: 16,
                  color: AppColors.primaryPurple,
                ),
                SizedBox(width: 6),
                Text(
                  "No audio found.",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Big Clay Play Button matching Screen 5
          SizedBox(
            width: double.infinity,
            child: ClayButton(
              text: "Play",
              icon: Icons.play_arrow_rounded,
              radius: 26,
              padding: const EdgeInsets.symmetric(vertical: 14),
              onPressed: () {
                // Play recent audio or trigger playback
              },
            ),
          ),
        ],
      ),
    );
  }
}

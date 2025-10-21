import 'package:logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:audioloca/theme.dart';
import 'package:audioloca/core/alert.dialog.dart';
import 'package:audioloca/local/controllers/user.service.dart';
import 'package:audioloca/spotify/controllers/oauth.service.dart';
import 'package:audioloca/tabs/tabs.routing.dart';
import 'package:audioloca/signup/signup.page.dart';

final log = Logger();
final userServices = UserServices();
final oauthServices = OAuthServices();

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  bool isAuthenticating = false;

  late AnimationController controller;
  late Animation<double> fadeAnimation;

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    fadeAnimation = CurvedAnimation(parent: controller, curve: Curves.easeIn);
    controller.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> handleLogin() async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      CustomAlertDialog.failed(context, 'Please fill in all fields.');
      return;
    }

    setState(() => isAuthenticating = true);

    try {
      final success = await userServices.localLogin(username, password);

      if (success) {
        log.i('[Flutter] Local login successful!');

        if (!mounted) return;
        CustomAlertDialog.success(context, 'Login successful!');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TabsRouting()),
        );
      } else {
        if (!mounted) return;
        CustomAlertDialog.failed(
          context,
          'Invalid username or password. Please try again.',
        );
      }
    } catch (e, stackTrace) {
      log.e('[Flutter] Local login error: $e $stackTrace');
      CustomAlertDialog.failed(context, e.toString());
    } finally {
      if (mounted) setState(() => isAuthenticating = false);
    }
  }

  Future<void> handleSpotifyLogin() async {
    setState(() => isAuthenticating = true);

    try {
      final oauth = await oauthServices.spotifyLogin();

      if (oauth) {
        log.i('[Flutter] Spotify login successful!');

        if (!mounted) return;
        CustomAlertDialog.success(context, 'Login successful!');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TabsRouting()),
        );
      } else {
        if (!mounted) return;
        CustomAlertDialog.failed(
          context,
          'Spotify login failed. Please try again.',
        );
      }
    } catch (e, stackTrace) {
      log.e('[Flutter] Error during Spotify authentication: $e $stackTrace');
      CustomAlertDialog.failed(context, e.toString());
    } finally {
      if (mounted) setState(() => isAuthenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.color3,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: FadeTransition(
            opacity: fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LOGO
                Image.asset(
                  'assets/images/audioloca.png',
                  width: 180,
                  height: 180,
                ),
                const SizedBox(height: 20),

                // APP NAME
                const Text('AUDIOLOCA', style: AppTextStyles.title),
                const SizedBox(height: 40),

                // USERNAME FIELD
                TextField(
                  controller: usernameController,
                  decoration: InputDecoration(
                    hintText: 'USERNAME',
                    hintStyle: const TextStyle(color: AppColors.color1),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: AppColors.color1,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: AppColors.color1,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // PASSWORD FIELD
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'PASSWORD',
                    hintStyle: const TextStyle(color: AppColors.color1),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: AppColors.color1,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: AppColors.color1,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // LOGIN BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isAuthenticating ? null : handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.color1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: isAuthenticating
                        ? const CircularProgressIndicator(
                            color: AppColors.light,
                            strokeWidth: 2.5,
                          )
                        : const Text(
                            'LOGIN',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.light,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // DIVIDER
                Row(
                  children: const [
                    Expanded(
                      child: Divider(thickness: 1, color: AppColors.color1),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        'OR',
                        style: TextStyle(color: AppColors.color1),
                      ),
                    ),
                    Expanded(
                      child: Divider(thickness: 1, color: AppColors.color1),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // CONTINUE WITH SPOTIFY BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isAuthenticating ? null : handleSpotifyLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.color1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: isAuthenticating
                        ? const CircularProgressIndicator(
                            color: AppColors.light,
                            strokeWidth: 2.5,
                          )
                        : const Text(
                            'CONTINUE WITH SPOTIFY',
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.light,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // SIGN UP LINK
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account? ",
                      style: TextStyle(color: AppColors.color1),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SignupPage()),
                        );
                      },
                      child: const Text(
                        'Sign up',
                        style: TextStyle(
                          color: AppColors.color1,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

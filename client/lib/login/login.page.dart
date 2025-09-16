import 'package:logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:audioloca/global/alert.dialog.dart';
import 'package:audioloca/services/oauth.service.dart';
import 'package:audioloca/tabs/tabs.routing.dart';
import 'package:audioloca/theme.dart';
import 'package:audioloca/signup/signup.page.dart';

final log = Logger();
final oauthService = OAuthService();

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
      final success = await oauthService.localLogin(username, password);

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
      CustomAlertDialog.failed(context, 'An error occurred: $e');
    } finally {
      if (mounted) setState(() => isAuthenticating = false);
    }
  }

  Future<void> handleSpotifyLogin() async {
    setState(() => isAuthenticating = true);

    try {
      final oauth = await oauthService.spotifyLogin();

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
      CustomAlertDialog.failed(context, 'An error occurred: $e');
    } finally {
      if (mounted) setState(() => isAuthenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.color3,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: FadeTransition(
            opacity: fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                SizedBox(
                  width: 150,
                  height: 150,
                  child: Image.asset('assets/images/audioloca.png'),
                ),
                const SizedBox(height: 16),
                Text('AUDIOLOCA', style: AppTextStyles.title),
                const SizedBox(height: 32),

                // Username field
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                const SizedBox(height: 16),

                // Password field
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 24),

                // Login button
                ElevatedButton(
                  onPressed: isAuthenticating ? null : handleLogin,
                  child: isAuthenticating
                      ? const CircularProgressIndicator(
                          color: AppColors.color1,
                          strokeWidth: 2.5,
                        )
                      : const Text('LOGIN'),
                ),
                const SizedBox(height: 20),

                Row(
                  children: const [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('OR'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 20),

                // Spotify login button
                ElevatedButton(
                  onPressed: isAuthenticating ? null : handleSpotifyLogin,
                  child: isAuthenticating
                      ? const CircularProgressIndicator(
                          color: AppColors.color1,
                          strokeWidth: 2.5,
                        )
                      : const Text('CONTINUE WITH SPOTIFY'),
                ),
                const SizedBox(height: 30),

                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignupPage()),
                    );
                  },
                  child: const Text('Don’t have an account? Sign up'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

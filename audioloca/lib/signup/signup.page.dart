import 'package:logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:audioloca/theme.dart';
import 'package:audioloca/core/alert.dialog.dart';
import 'package:audioloca/local/controllers/user.service.dart';
import 'package:audioloca/spotify/controllers/oauth.service.dart';
import 'package:audioloca/tabs/tabs.routing.dart';
import 'package:audioloca/login/login.page.dart';

final log = Logger();
final userServices = UserServices();
final ouathServices = OAuthServices();

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});
  @override
  State<SignupPage> createState() => SignupPageState();
}

class SignupPageState extends State<SignupPage>
    with SingleTickerProviderStateMixin {
  bool isAuthenticating = false;

  late AnimationController controller;
  late Animation<double> fadeAnimation;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

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
    emailController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> handleSignup() async {
    final email = emailController.text.trim();
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (email.isEmpty ||
        username.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      CustomAlertDialog.failed(context, 'Please fill in all fields.');
      return;
    }

    if (username.length <= 6 || username.length >= 50) {
      CustomAlertDialog.failed(
        context,
        'Your username must be at least 6 characters long.',
      );
      return;
    }

    if (password.length <= 6 || password.length >= 50) {
      CustomAlertDialog.failed(
        context,
        'Your password must be at least 6 characters long.',
      );
      return;
    }

    if (password != confirmPassword) {
      CustomAlertDialog.failed(
        context,
        'Passwords do not match. Please try again.',
      );
      return;
    }

    setState(() => isAuthenticating = true);

    try {
      final success = await userServices.localSignup(email, username, password);

      if (success) {
        log.i('[Flutter] Signup successful!');

        if (!mounted) return;
        CustomAlertDialog.success(
          context,
          'Account created! You can now login.',
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      } else {
        if (!mounted) return;
        CustomAlertDialog.failed(context, 'Signup failed. Try again.');
      }
    } catch (e, stackTrace) {
      log.e('[Flutter] Signup error: $e $stackTrace');
      CustomAlertDialog.failed(context, e.toString());
    } finally {
      if (mounted) setState(() => isAuthenticating = false);
    }
  }

  Future<void> handleSpotifyLogin() async {
    setState(() => isAuthenticating = true);

    try {
      final oauth = await ouathServices.spotifyLogin();

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
                Text('CREATE ACCOUNT', style: AppTextStyles.title),
                const SizedBox(height: 32),

                // Email field
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  maxLength: 255,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 16),

                // Username field
                TextField(
                  controller: usernameController,
                  maxLength: 50,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                const SizedBox(height: 16),

                // Password field
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  maxLength: 50,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 16),

                // Confirm Password field
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                  ),
                ),
                const SizedBox(height: 24),

                // Signup button
                ElevatedButton(
                  onPressed: isAuthenticating ? null : handleSignup,
                  child: isAuthenticating
                      ? const CircularProgressIndicator(
                          color: AppColors.color1,
                          strokeWidth: 2.5,
                        )
                      : const Text('SIGN UP'),
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

                // Spotify signup button
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
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                  child: const Text('Already have an account? Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

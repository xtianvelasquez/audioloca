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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
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

              // EMAIL FIELD
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  hintText: 'EMAIL',
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

              // CONFIRM PASSWORD FIELD
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'CONFIRM PASSWORD',
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

              // SIGNUP BUTTON
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isAuthenticating ? null : handleSignup,
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
                          'SIGNUP',
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

              // SPOTIFY BUTTON
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

              // LOGIN LINK
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Already have an account? ",
                    style: TextStyle(color: AppColors.color1),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    child: const Text(
                      'Login',
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
    );
  }
}

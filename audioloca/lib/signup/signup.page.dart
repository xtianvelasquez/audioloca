import 'package:logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:audioloca/theme.dart';
import 'package:audioloca/core/alert.dialog.dart';
import 'package:audioloca/local/services/user.service.dart';
import 'package:audioloca/spotify/services/oauth.service.dart';
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

  InputDecoration _inputDeco(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13,
      ),
      prefixIcon: Icon(
        icon,
        color: AppColors.primaryPurple,
        size: 20,
      ),
      filled: true,
      fillColor: AppColors.pillBg.withValues(alpha: 0.45),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMid,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.background,
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            child: FadeTransition(
              opacity: fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: ClayDecorations.card(radius: 32),
                    child: Column(
                      children: [
                        // Logo inside clay circle
                        Container(
                          width: 84,
                          height: 84,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryPurple.withValues(
                                  alpha: 0.25,
                                ),
                                offset: const Offset(2, 6),
                                blurRadius: 12,
                              ),
                              const BoxShadow(
                                color: Colors.white,
                                offset: Offset(-2, -2),
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
                        const SizedBox(height: 14),

                        const Text(
                          'Join AudioLoca',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.dark,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Create your account to start listening',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // EMAIL FIELD
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(
                            color: AppColors.dark,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: _inputDeco(
                            'Email',
                            Icons.email_outlined,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // USERNAME FIELD
                        TextField(
                          controller: usernameController,
                          style: const TextStyle(
                            color: AppColors.dark,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: _inputDeco(
                            'Username (min 6 chars)',
                            Icons.person_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // PASSWORD FIELD
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          style: const TextStyle(
                            color: AppColors.dark,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: _inputDeco(
                            'Password',
                            Icons.lock_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // CONFIRM PASSWORD FIELD
                        TextField(
                          controller: confirmPasswordController,
                          obscureText: true,
                          style: const TextStyle(
                            color: AppColors.dark,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: _inputDeco(
                            'Confirm Password',
                            Icons.lock_clock_outlined,
                          ),
                        ),
                        const SizedBox(height: 22),

                        // SIGNUP BUTTON
                        SizedBox(
                          width: double.infinity,
                          child: ClayButton(
                            text: isAuthenticating
                                ? 'CREATING ACCOUNT...'
                                : 'CREATE ACCOUNT',
                            icon: isAuthenticating
                                ? null
                                : Icons.arrow_forward_rounded,
                            radius: 24,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            onPressed: isAuthenticating ? null : handleSignup,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // DIVIDER
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: AppColors.pillBg,
                                thickness: 1.5,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10.0),
                              child: Text(
                                'OR',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: AppColors.pillBg,
                                thickness: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // SPOTIFY BUTTON
                        SizedBox(
                          width: double.infinity,
                          child: ClayButton(
                            text: 'CONTINUE WITH SPOTIFY',
                            icon: Icons.graphic_eq_rounded,
                            isSecondary: true,
                            radius: 24,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            onPressed:
                                isAuthenticating ? null : handleSpotifyLogin,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // LOGIN LINK
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Already have an account? ",
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                          );
                        },
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
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
      ),
    );
  }
}

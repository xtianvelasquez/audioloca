import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:audioloca/services/login.service.dart';
import 'package:audioloca/tabs/tabs.routing.dart';
import 'package:audioloca/theme.dart';

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
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Center(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 150,
                            height: 150,
                            child: Image.asset(
                              'assets/images/audioloca.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text('AUDIOLOCA', style: AppTextStyles.title),
                          const SizedBox(height: 32),
                          ElevatedButton(
                            onPressed: isAuthenticating
                                ? null
                                : () async {
                                    setState(() => isAuthenticating = true);

                                    try {
                                      final oauth = await oauthService
                                          .spotifyLogin();

                                      if (oauth) {
                                        log.i("[Flutter] Login successful!");
                                        _showSnackBar("Login successful!");
                                        if (context.mounted) {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const TabsRouting(),
                                            ),
                                          );
                                        }
                                      } else {
                                        log.d(
                                          "[Flutter] Login failed silently.",
                                        );
                                        _showSnackBar(
                                          "Login failed. Please try again.",
                                        );
                                      }
                                    } catch (e) {
                                      log.d(
                                        "[Flutter] Error during Spotify authentication: $e",
                                      );
                                      _showSnackBar("An error occurred: $e");
                                    } finally {
                                      if (mounted) {
                                        setState(
                                          () => isAuthenticating = false,
                                        );
                                      }
                                    }
                                  },
                            child: isAuthenticating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text('LOGIN WITH SPOTIFY'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

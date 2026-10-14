import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/business/emotion.recognition.dart';
import 'package:audioloca/login/login.page.dart';
import 'package:audioloca/tabs/tabs.routing.dart';
import 'package:audioloca/theme.dart';

final storage = SecureStorageService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await GeolocatorPlatform.instance.isLocationServiceEnabled();
  } catch (e) {
    debugPrint('Geolocator initialization failed: $e');
  }

  await emotionService.loadModels();

  runApp(const AudioLoca());
}

class AudioLoca extends StatelessWidget {
  const AudioLoca({super.key});

  Future<bool> isAuthenticated() async {
    final token = await storage.getJwtToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AudioLoca',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: FutureBuilder<bool>(
        future: isAuthenticated(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: AppColors.bgMid,
              body: Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryPurple,
                ),
              ),
            );
          }

          if (snapshot.hasData && snapshot.data == true) {
            return const TabsRouting();
          } else {
            return const LoginPage();
          }
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/core/emotion.recognition.dart';
import 'package:audioloca/login/login.page.dart';
import 'package:audioloca/tabs/tabs.routing.dart';

final storage = SecureStorageService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await emotionService.loadModel();
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
      home: FutureBuilder<bool>(
        future: isAuthenticated(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData && snapshot.data == true) {
            return TabsRouting();
          } else {
            return LoginPage();
          }
        },
      ),
    );
  }
}

import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:audioloca/environment.dart';
import 'package:audioloca/core/secure.storage.dart';

final log = Logger();
final storage = SecureStorageService();

class UserServices {
  final http.Client client;

  UserServices({http.Client? client}) : client = client ?? http.Client();

  Future<bool> localLogin(String username, String password) async {
    final uri = Uri.parse('${Environment.audiolocaBaseUrl}/audioloca/callback');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode >= 400) {
        log.e('[Flutter] Login failed: ${response.body}');
        throw Exception('Login failed: ${response.body}');
      }

      final tokenData = jsonDecode(response.body);

      if (tokenData is! Map || !tokenData.containsKey('jwt_token')) {
        throw Exception('Unexpected response structure.');
      }

      final jwtToken = tokenData['jwt_token'];
      if (jwtToken == null || jwtToken.isEmpty) {
        throw Exception('No token returned from server.');
      }

      await storage.saveJwtToken(jwtToken);
      log.i('[Flutter] JWT token saved successfully.');
      return true;
    } catch (e, stackTrace) {
      log.e('[Flutter] Local login error: $e\n$stackTrace');
      throw Exception('Login error: $e');
    }
  }

  Future<bool> localSignup(
    String email,
    String username,
    String password,
  ) async {
    final uri = Uri.parse('${Environment.audiolocaBaseUrl}/audioloca/signup');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode >= 400) {
        log.e('[Flutter] Signup failed: ${response.body}');
        throw Exception('Signup failed: ${response.body}');
      }

      log.i('[Flutter] Signup successful.');
      return true;
    } catch (e, stackTrace) {
      log.e('[Flutter] Local signup error: $e $stackTrace');
      throw Exception('Signup error: $e');
    }
  }
}

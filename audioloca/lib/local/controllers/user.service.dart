import 'dart:convert';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:audioloca/environment.dart';
import 'package:audioloca/local/models/user.model.dart';
import 'package:audioloca/core/secure.storage.dart';

final log = Logger();
final storage = SecureStorageService();

class UserEndpoints {
  static const String login = '/audioloca/callback';
  static const String signup = '/audioloca/signup';
  static const String readProfile = '/user/read';
  static const String logout = '/logout';
}

class UserServices {
  final http.Client client;

  UserServices({http.Client? client}) : client = client ?? http.Client();

  // =======================
  // Login
  // =======================
  Future<bool> localLogin(String username, String password) async {
    // _post now returns the token string
    final jwtToken = await _post<String>(
      UserEndpoints.login,
      body: {'username': username, 'password': password},
      parser: (data) {
        if (data is Map && data.containsKey('jwt_token')) {
          final token = data['jwt_token'];
          if (token != null && token.isNotEmpty) {
            return token; // Return the JWT token as String
          }
        }
        throw Exception('Invalid login response format.');
      },
    );

    // Save the token
    await storage.saveJwtToken(jwtToken);
    log.i('[Flutter] JWT token saved successfully.');
    return true;
  }

  // =======================
  // Signup
  // =======================
  Future<bool> localSignup(
    String email,
    String username,
    String password,
  ) async {
    return _post<bool>(
      UserEndpoints.signup,
      body: {'email': email, 'username': username, 'password': password},
      parser: (data) => true,
    );
  }

  // =======================
  // Fetch user profile
  // =======================
  Future<User> fetchUserProfile() async {
    final uri = Uri.parse('${Environment.audiolocaBaseUrl}/user/read');

    try {
      final jwtToken = await storage.getJwtToken();
      if (jwtToken == null || jwtToken.isEmpty) {
        throw Exception('No token returned from server.');
      }

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode >= 400) {
        throw Exception('Error fetching user profile: ${response.body}');
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        throw Exception('Unexpected user profile format.');
      }

      // Parse JSON into User model
      return User.fromJson(data);
    } catch (e, stackTrace) {
      log.e('[Flutter] Error fetching user profile: $e\n$stackTrace');
      throw Exception('Login error: $e');
    }
  }

  // =======================
  // Logout
  // =======================
  Future<bool> logout() async {
    final jwtToken = await storage.getJwtToken();
    if (jwtToken == null || jwtToken.isEmpty) {
      return false;
    }

    return _post<bool>(
      UserEndpoints.logout,
      headers: _headers(jwtToken),
      body: {},
      parser: (data) => true,
    );
  }

  // =======================
  // Reusable GET / POST
  // =======================
  Future<T> _post<T>(
    String endpoint, {
    Map<String, String>? headers,
    required Map<String, dynamic> body,
    required T Function(dynamic) parser,
  }) async {
    final url = Uri.parse('${Environment.audiolocaBaseUrl}$endpoint');
    try {
      final response = await client.post(
        url,
        headers: headers ?? {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return parser(jsonDecode(response.body));
      }

      throw HttpException(
        'POST $endpoint failed: ${response.statusCode} ${response.body}',
      );
    } catch (e, stackTrace) {
      log.e('[Flutter] POST $endpoint error $e $stackTrace');
      rethrow;
    }
  }

  Map<String, String> _headers(String jwtToken) => {
    'Authorization': 'Bearer $jwtToken',
    'Content-Type': 'application/json',
  };
}

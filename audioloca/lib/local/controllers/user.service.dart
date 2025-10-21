import 'dart:convert';
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
  static const String logout = '/logout';
  static const String readProfile = '/user/read';
}

class UserServices {
  final http.Client client;

  UserServices({http.Client? client}) : client = client ?? http.Client();

  // =======================
  // Login
  // =======================
  Future<bool> localLogin(String username, String password) async {
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
        throw 'Invalid login response format.';
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
  // Fetch user profile
  // =======================
  Future<User> fetchUserProfile() async {
    final uri = Uri.parse(
      '${Environment.audiolocaBaseUrl}${UserEndpoints.readProfile}',
    );

    try {
      final jwtToken = await storage.getJwtToken();
      if (jwtToken == null || jwtToken.isEmpty) {
        throw 'No token returned from server.';
      }

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode >= 400) {
        throw 'Error fetching user profile: ${response.body}';
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        throw 'Unexpected user profile format.';
      }

      return User.fromJson(data);
    } catch (e, stackTrace) {
      log.e('[Flutter] Error fetching user profile: $e $stackTrace');
      rethrow;
    }
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

      if (response.statusCode == 200 || response.statusCode == 201) {
        return parser(jsonDecode(response.body));
      }

      String message = 'Request failed with status: ${response.statusCode}.';

      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('detail')) {
          message = decoded['detail'];
        } else if (decoded is Map && decoded.containsKey('message')) {
          message = decoded['message'];
        }
      } catch (_) {
        message = response.body.toString();
      }

      throw message;
    } catch (e, stackTrace) {
      log.e('[Flutter] POST $endpoint error: $e\n$stackTrace');
      rethrow;
    }
  }

  Map<String, String> _headers(String jwtToken) => {
    'Authorization': 'Bearer $jwtToken',
    'Content-Type': 'application/json',
  };
}

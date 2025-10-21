import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import 'package:audioloca/environment.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/core/utils.dart';

final log = Logger();
final storage = SecureStorageService();

class OAuthServices {
  Future<bool> spotifyLogin() async {
    final existingCodeVerifier = await storage.getCodeVerifier();
    late final String codeVerifier;

    if (existingCodeVerifier == null) {
      codeVerifier = generateCodeVerifier();
      await storage.saveCodeVerifier(codeVerifier);
    } else {
      codeVerifier = existingCodeVerifier;
    }

    final codeChallenge = generateCodeChallenge(codeVerifier);

    final scope =
        'user-read-email user-read-private user-read-currently-playing user-modify-playback-state user-read-playback-state app-remote-control';
    final oauthUrl = Uri.https('accounts.spotify.com', '/authorize', {
      'response_type': 'code',
      'client_id': Environment.spotifyClientId,
      'redirect_uri': Environment.spotifyRedirectUri,
      'scope': scope,
      'code_challenge_method': 'S256',
      'code_challenge': codeChallenge,
    });

    final result = await FlutterWebAuth2.authenticate(
      url: oauthUrl.toString(),
      callbackUrlScheme: 'audioloca',
    );

    final uri = Uri.parse(result);
    final code = uri.queryParameters['code'];
    if (code == null) {
      await storage.deleteCodeVerifier();
      throw 'Authorization code not found in the response.';
    }

    final savedVerifier = await storage.getCodeVerifier();

    final response = await http.post(
      Uri.parse('${Environment.audiolocaBaseUrl}/spotify/callback'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code, 'code_verifier': savedVerifier}),
    );

    if (response.statusCode != 200) {
      await storage.deleteCodeVerifier();
      throw 'Backend token exchange failed: ${response.body}';
    }

    final tokenData = jsonDecode(response.body);
    final accessToken = tokenData['access_token'];
    final expirationRaw = tokenData['expires_at'];
    final expiration = DateTime.tryParse(expirationRaw);
    final refreshToken = tokenData['refresh_token'];
    final jwtToken = tokenData['jwt_token'];

    if (expiration != null) {
      await storage.saveExpiresAt(expiration.toIso8601String());
    }
    await storage.saveAccessToken(accessToken);
    await storage.saveRefreshToken(refreshToken);
    await storage.saveJwtToken(jwtToken);
    await storage.deleteCodeVerifier();

    log.i('[Flutter] Access Token: $accessToken');
    log.i('[Flutter] Expires At: $expiration');
    log.i('[Flutter] Refresh Token: $refreshToken');
    log.i('[Flutter] JWT Token: $jwtToken');

    return true;
  }
}

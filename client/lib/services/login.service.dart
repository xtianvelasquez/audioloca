import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:audioloca/environment.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/core/utils.dart';

final log = Logger();
final storage = SecureStorageService();

class OAuthService {
  Future<bool> spotifyLogin() async {
    final existingCodeVerifier = await storage.getCodeVerifier();
    late final String codeVerifier;

    if (existingCodeVerifier == null) {
      codeVerifier = generateCodeVerifier();
      await storage.saveCodeVerifier(codeVerifier);
      log.i("[Flutter] Code Verifier saved: $codeVerifier");
    } else {
      codeVerifier = existingCodeVerifier;
      log.i("[Flutter] Code Verifier loaded from storage: $codeVerifier");
    }

    final codeChallenge = generateCodeChallenge(codeVerifier);

    log.i("[Flutter] Code Verifier: $codeVerifier");
    log.i("[Flutter] Code Challenge: $codeChallenge");

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
    log.i("[Flutter] OAuth URL: $oauthUrl");

    final result = await FlutterWebAuth2.authenticate(
      url: oauthUrl.toString(),
      callbackUrlScheme: 'audioloca',
    );

    final uri = Uri.parse(result);
    final code = uri.queryParameters['code'];
    log.i("[Flutter] Code: $code");

    if (code == null) {
      log.d('[Flutter] Clearing code verifier due to failed login flow.');
      await storage.deleteCodeVerifier(); // before throwing exception
      throw Exception('Authorization code not found in the response.');
    }

    final savedVerifier = await storage.getCodeVerifier();
    log.i("[Flutter] Saved Verifier: $savedVerifier");

    final response = await http.post(
      Uri.parse('${Environment.audiolocaBaseUrl}/spotify/callback'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code, 'code_verifier': savedVerifier}),
    );

    if (response.statusCode == 200) {
      final tokenData = jsonDecode(response.body);
      final accessToken = tokenData['access_token'];
      final expirationRaw = tokenData['expires_at'];
      final expiration = DateTime.tryParse(expirationRaw);
      final refreshToken = tokenData['refresh_token'];
      final jwtToken = tokenData['jwt_token'];

      if (expiration != null) {
        await storage.saveExpiresAt(expiration.toIso8601String());
      } else {
        log.e('[Flutter] Failed to parse expiration date: $expirationRaw');
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
    } else {
      log.d('[Flutter] Failed to exchange token: ${response.body}');
      log.d('[Flutter] Clearing code verifier due to failed login flow.');
      await storage.deleteCodeVerifier();
      throw Exception('Backend token exchange failed.');
    }
  }
}

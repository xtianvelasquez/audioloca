import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';

String generateCodeVerifier([int length = 64]) {
  final random = Random.secure();
  final values = List<int>.generate(length, (_) => random.nextInt(256));
  return base64UrlEncode(values)
      .replaceAll('=', '')
      .replaceAll('+', '-')
      .replaceAll('/', '_')
      .substring(0, length);
}

String generateCodeChallenge(String codeVerifier) {
  final bytes = utf8.encode(codeVerifier);
  final digest = sha256.convert(bytes);
  return base64UrlEncode(digest.bytes).replaceAll('=', '');
}

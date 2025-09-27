import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:audioloca/environment.dart';

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

String formatLocalTrackDuration(String rawDuration) {
  try {
    final parts = rawDuration.split(':');
    final minutes = int.parse(parts[1]);
    final seconds = int.parse(parts[2].split('+')[0]);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  } catch (e) {
    return rawDuration;
  }
}

String formatSpotifyTrackDuration(int ms) {
  final seconds = (ms / 1000).round();
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
}

String resolveImageUrl(String? imageUrl) {
  if (imageUrl == null || imageUrl.isEmpty) {
    return 'https://via.placeholder.com/50';
  }

  final isAbsolute =
      imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
  return isAbsolute ? imageUrl : '${Environment.audiolocaBaseUrl}/$imageUrl';
}

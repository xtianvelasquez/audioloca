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

String formatDuration(String rawDuration) {
  try {
    final parsed = DateTime.parse(rawDuration);

    final duration = Duration(
      hours: parsed.hour,
      minutes: parsed.minute,
      seconds: parsed.second,
    );

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    return hours > 0 ? "$hours:$minutes:$seconds" : "$minutes:$seconds";
  } catch (e) {
    return rawDuration;
  }
}

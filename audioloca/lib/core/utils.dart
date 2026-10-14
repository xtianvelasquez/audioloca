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

/// Extracts a clean, user-friendly error string from an HTTP response,
/// preventing leakage of HTTP status codes (404, 500, etc.) or raw HTML/system dumps.
String parseApiResponseError(
  dynamic responseOrBody, {
  int? statusCode,
  String defaultMessage = 'An error occurred. Please try again.',
}) {
  try {
    String rawBody = '';
    int code = statusCode ?? 0;

    if (responseOrBody is String) {
      rawBody = responseOrBody;
    } else if (responseOrBody != null && responseOrBody.body != null) {
      rawBody = responseOrBody.body.toString();
      code = responseOrBody.statusCode ?? code;
    }

    if (rawBody.trim().isEmpty) {
      return _fallbackForStatusCode(code, defaultMessage);
    }

    // If it looks like HTML or system crash trace, do not display raw body
    if (rawBody.contains('<html') ||
        rawBody.contains('<!DOCTYPE') ||
        rawBody.contains('Traceback (most recent call last)')) {
      return _fallbackForStatusCode(code, defaultMessage);
    }

    final decoded = jsonDecode(rawBody);
    if (decoded is Map) {
      if (decoded['detail'] != null &&
          decoded['detail'] is String &&
          (decoded['detail'] as String).trim().isNotEmpty) {
        return sanitizeErrorMessage(decoded['detail']);
      }
      if (decoded['message'] != null &&
          decoded['message'] is String &&
          (decoded['message'] as String).trim().isNotEmpty) {
        return sanitizeErrorMessage(decoded['message']);
      }
    }
  } catch (_) {
    // If json decoding failed, fallback
  }

  return _fallbackForStatusCode(statusCode ?? 0, defaultMessage);
}

String _fallbackForStatusCode(int code, String defaultMessage) {
  switch (code) {
    case 400:
      return 'Invalid request. Please check your inputs.';
    case 401:
      return 'Invalid credentials or session expired. Please log in again.';
    case 403:
      return 'You do not have permission to perform this action.';
    case 404:
      return 'The requested resource was not found.';
    case 409:
      return 'A conflict occurred. Please try again.';
    case 422:
      return 'Validation error. Please verify your details.';
    case 500:
    case 502:
    case 503:
    case 504:
      return 'Server error. Please try again later.';
    default:
      return defaultMessage;
  }
}

/// Sanitizes any raw exception or error message to ensure no "Exception: ",
/// HTTP status codes, or internal stack traces are shown to users.
String sanitizeErrorMessage(
  dynamic error, {
  String defaultMessage = 'An unexpected error occurred. Please try again.',
}) {
  if (error == null) return defaultMessage;
  String text = error.toString().trim();

  // Strip Exception / FormatException prefixes
  if (text.startsWith('Exception: ')) {
    text = text.substring('Exception: '.length).trim();
  } else if (text.startsWith('FormatException: ')) {
    text = text.substring('FormatException: '.length).trim();
  }

  // Remove status code patterns like "Request failed with status: 404."
  final statusCodeRegex = RegExp(
    r'Request failed with status:\s*\d+\.?',
    caseSensitive: false,
  );
  if (statusCodeRegex.hasMatch(text)) {
    return 'Unable to complete request. Please try again.';
  }

  // If HTML or system trace leaked
  if (text.contains('<html') ||
      text.contains('<!DOCTYPE') ||
      text.contains('Traceback')) {
    return 'Server error. Please try again later.';
  }

  // If it's a socket or client network exception
  final lower = text.toLowerCase();
  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection refused') ||
      lower.contains('network is unreachable')) {
    return 'Network connection error. Please check your internet connection.';
  }

  return text.isNotEmpty ? text : defaultMessage;
}

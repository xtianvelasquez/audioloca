import 'dart:io';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:audioloca/environment.dart';
import 'package:audioloca/models/emotions.model.dart';

final log = Logger();

class EmotionServices {
  final http.Client client;

  EmotionServices({http.Client? client}) : client = client ?? http.Client();

  Future<List<Emotions>> readEmotions() async {
    final url = Uri.parse(
      '${Environment.audiolocaBaseUrl}/audioloca/emotions/read',
    );

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((json) => Emotions.fromJson(json)).toList();
        } else {
          throw FormatException('Unexpected albums response format');
        }
      } else {
        throw HttpException('Failed to fetch albums: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      log.e('Error fetching albums $e $stackTrace');
      rethrow;
    }
  }
}

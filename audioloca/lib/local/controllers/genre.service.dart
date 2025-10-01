import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:audioloca/environment.dart';
import 'package:audioloca/local/models/genres.model.dart';

final log = Logger();

class GenreServices {
  final http.Client client;

  GenreServices({http.Client? client}) : client = client ?? http.Client();

  Future<List<Genres>> readGenres() async {
    final url = Uri.parse(
      '${Environment.audiolocaBaseUrl}/audioloca/genres/read',
    );

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((json) => Genres.fromJson(json)).toList();
        } else {
          throw FormatException('Unexpected genre response format');
        }
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

      throw Exception(message);
    } catch (e, stackTrace) {
      log.e('Error fetching albums: $e $stackTrace');
      rethrow;
    }
  }
}

import 'dart:io';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:audioloca/environment.dart';
import 'package:audioloca/models/user.model.dart';

final log = Logger();

class UserServices {
  final http.Client client;

  UserServices({http.Client? client}) : client = client ?? http.Client();

  Future<List<User>> readEmotions(String jwtToken) async {
    final url = Uri.parse('${Environment.audiolocaBaseUrl}/user/read');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((json) => User.fromJson(json)).toList();
        } else {
          throw FormatException('Unexpected user response format');
        }
      } else {
        throw HttpException('Failed to fetch user: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      log.e('Error fetching user $e $stackTrace');
      rethrow;
    }
  }
}

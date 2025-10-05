import 'dart:io';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:audioloca/environment.dart';
import 'package:audioloca/local/models/audio.model.dart';

final log = Logger();

class ApiEndpoints {
  static const String locationAudio = '/audioloca/audio/location';
  static const String audioGenre = '/audioloca/audio/genre';
  static const String audioAlbum = '/audioloca/audio/album';
  static const String readAudios = '/audioloca/audios/read';
  static const String readAudio = '/audioloca/audio/read';
  static const String searchAudio = '/audioloca/audio/search';
  static const String createAudio = '/audioloca/audio/create';
  static const String globalAudio = '/audioloca/audio/global';
}

class AudioServices {
  final http.Client client;

  AudioServices({http.Client? client}) : client = client ?? http.Client();

  // =======================
  // POST audio by location
  // =======================
  Future<List<Audio>> readAudioLocation(
    double latitude,
    double longitude,
  ) async {
    return _post<List<Audio>>(
      ApiEndpoints.locationAudio,
      headers: {'Content-Type': 'application/json'},
      body: {'latitude': latitude, 'longitude': longitude},
      parser: (data) {
        if (data is List) {
          return data.map((json) => Audio.fromJson(json)).toList();
        }
        throw FormatException('Unexpected audio location format.');
      },
    );
  }

  // =======================
  // POST audio by genre
  // =======================
  Future<List<Audio>> readAudioGenre(int genreId) async {
    return _post<List<Audio>>(
      ApiEndpoints.audioGenre,
      headers: {'Content-Type': 'application/json'},
      body: {'genre_id': genreId},
      parser: (data) {
        if (data is List) {
          return data.map((json) => Audio.fromJson(json)).toList();
        }
        throw FormatException('Unexpected audio genre format.');
      },
    );
  }

  // =======================
  // POST audios from an album
  // =======================
  Future<List<Audio>> readAudioAlbum(String jwtToken, int albumId) async {
    return _post<List<Audio>>(
      ApiEndpoints.audioAlbum,
      headers: _headers(jwtToken),
      body: {'album_id': albumId},
      parser: (data) {
        if (data is List) {
          return data.map((json) => Audio.fromJson(json)).toList();
        }
        throw FormatException('Unexpected album audio format.');
      },
    );
  }

  // =======================
  // GET all audios
  // =======================
  Future<List<Audio>> readAudios(String jwtToken) async {
    return _get<List<Audio>>(
      ApiEndpoints.readAudios,
      headers: _headers(jwtToken),
      parser: (data) {
        if (data is List) {
          return data.map((json) => Audio.fromJson(json)).toList();
        }
        throw FormatException('Unexpected audio list format.');
      },
    );
  }

  // =======================
  // POST specific audio
  // =======================
  Future<Audio> readAudio(String jwtToken, int audioId) async {
    return _post<Audio>(
      ApiEndpoints.readAudio,
      headers: _headers(jwtToken),
      body: {'audio_id': audioId},
      parser: (data) {
        if (data is Map<String, dynamic>) {
          return Audio.fromJson(data);
        }
        throw FormatException('Unexpected audio format.');
      },
    );
  }

  // =======================
  // POST searched audio
  // =======================
  Future<List<Audio>> searchForAudio(String query) async {
    final endpoint =
        '${ApiEndpoints.searchAudio}?query=${Uri.encodeComponent(query)}';

    return _get<List<Audio>>(
      endpoint,
      headers: {},
      parser: (data) {
        if (data is List) {
          return data.map((item) => Audio.fromJson(item)).toList();
        }
        throw FormatException('Unexpected audio list format.');
      },
    );
  }

  // =======================
  // CREATE audio with multipart upload
  // =======================
  Future<bool> createAudio({
    required int albumID,
    required int genreID,
    required String duration,
    required String visibility,
    required String audioTitle,
    required File audioRecord,
    required String jwtToken,
  }) async {
    final uri = Uri.parse(
      '${Environment.audiolocaBaseUrl}${ApiEndpoints.createAudio}',
    );

    final supportedAudioTypes = [
      'audio/mpeg', // standard MIME for mp3
      'audio/aac',
      'audio/wav',
      'audio/x-wav',
    ];

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $jwtToken'
      ..fields['album_id'] = albumID.toString()
      ..fields['genre_id'] = genreID.toString()
      ..fields['duration'] = duration
      ..fields['visibility'] = visibility
      ..fields['audio_title'] = audioTitle;

    await _addMultipartFile(
      request,
      'audio_record',
      audioRecord,
      supportedAudioTypes,
      'audio/mpeg',
    );

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (streamedResponse.statusCode == 201) {
        log.i('Audio created successfully: ${response.body}');
        return true;
      } else {
        log.w(
          'Audio creation failed: ${streamedResponse.statusCode} ${response.body}',
        );
        return false;
      }
    } catch (e, stackTrace) {
      log.e('[Flutter] Error creating audio: $e $stackTrace');
      return false;
    }
  }

  // =======================
  // GET global audios
  // =======================
  Future<List<Audio>> readGlobalAudios() async {
    return _get<List<Audio>>(
      ApiEndpoints.globalAudio,
      headers: {},
      parser: (data) {
        if (data is List) {
          return data.map((json) => Audio.fromJson(json)).toList();
        }
        throw FormatException('Unexpected audio list format.');
      },
    );
  }

  // =======================
  // Helpers
  // =======================
  Future<T> _get<T>(
    String endpoint, {
    required Map<String, String> headers,
    required T Function(dynamic) parser,
  }) async {
    final url = Uri.parse('${Environment.audiolocaBaseUrl}$endpoint');
    try {
      final response = await client.get(url, headers: headers);
      if (response.statusCode == 200) {
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

      throw Exception(message);
    } catch (e, stackTrace) {
      log.e('[Fluttter] GET $endpoint error $e $stackTrace');
      rethrow;
    }
  }

  Future<T> _post<T>(
    String endpoint, {
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    required T Function(dynamic) parser,
  }) async {
    final url = Uri.parse('${Environment.audiolocaBaseUrl}$endpoint');
    try {
      final response = await client.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
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

      throw Exception(message);
    } catch (e, stackTrace) {
      log.e('[Flutter] POST $endpoint error $e $stackTrace');
      rethrow;
    }
  }

  Future<void> _addMultipartFile(
    http.MultipartRequest request,
    String fieldName,
    File file,
    List<String> allowedMime,
    String defaultMime,
  ) async {
    final mime = lookupMimeType(file.path);
    final safeMime = allowedMime.contains(mime) ? mime! : defaultMime;
    request.files.add(
      await http.MultipartFile.fromPath(
        fieldName,
        file.path,
        contentType: MediaType.parse(safeMime),
      ),
    );
  }

  Map<String, String> _headers(String jwtToken) => {
    'Authorization': 'Bearer $jwtToken',
    'Content-Type': 'application/json',
  };
}

import 'dart:io';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:audioloca/environment.dart';
import 'package:audioloca/local/models/album.model.dart';
import 'package:audioloca/core/utils.dart';

final log = Logger();

class ApiEndpoints {
  static const String readAlbums = '/audioloca/albums/read';
  static const String readAlbum = '/audioloca/album/read';
  static const String createAlbum = '/audioloca/album/create';
  static const String deleteAlbum = '/audioloca/album/delete';
}

class AlbumServices {
  final http.Client client;

  AlbumServices({http.Client? client}) : client = client ?? http.Client();

  // =======================
  // GET all albums
  // =======================
  Future<List<Album>> readAlbums(String jwtToken) async {
    final url = Uri.parse(
      '${Environment.audiolocaBaseUrl}${ApiEndpoints.readAlbums}',
    );

    try {
      final response = await client.get(url, headers: _headers(jwtToken));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((json) => Album.fromJson(json)).toList();
        } else {
          throw const FormatException('Unexpected albums response format.');
        }
      }

      throw parseApiResponseError(
        response,
        defaultMessage: 'Failed to fetch albums.',
      );
    } catch (e, stackTrace) {
      log.e('[Flutter] Error fetching albums: $e $stackTrace');
      rethrow;
    }
  }

  // =======================
  // POST specific album
  // =======================
  Future<Album> readAlbum(String jwtToken, int albumId) async {
    final url = Uri.parse(
      '${Environment.audiolocaBaseUrl}${ApiEndpoints.readAlbum}',
    );

    try {
      final response = await client.post(
        url,
        headers: _headers(jwtToken),
        body: jsonEncode({'album_id': albumId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return Album.fromJson(data);
        } else {
          throw const FormatException('Unexpected album response format.');
        }
      }

      throw parseApiResponseError(
        response,
        defaultMessage: 'Failed to fetch album details.',
      );
    } catch (e, stackTrace) {
      log.e('[Flutter] Error fetching specific album: $e $stackTrace');
      rethrow;
    }
  }

  // =======================
  // POST delete specific album
  // =======================
  Future<Album> deleteSpecificAlbum(String jwtToken, int albumId) async {
    final url = Uri.parse(
      '${Environment.audiolocaBaseUrl}${ApiEndpoints.deleteAlbum}',
    );

    try {
      final response = await client.post(
        url,
        headers: _headers(jwtToken),
        body: jsonEncode({'album_id': albumId}),
      );

      if (response.statusCode == 200) {
        return Album.empty();
      }

      throw parseApiResponseError(
        response,
        defaultMessage: 'Failed to delete album.',
      );
    } catch (e, stackTrace) {
      log.e('[Flutter] Error deleting specific album: $e $stackTrace');
      rethrow;
    }
  }

  // =======================
  // CREATE album with multipart upload
  // =======================
  Future<bool> createAlbum({
    required String albumName,
    required File albumCover,
    required String jwtToken,
  }) async {
    final uri = Uri.parse(
      '${Environment.audiolocaBaseUrl}${ApiEndpoints.createAlbum}',
    );

    final supportedPhotoTypes = ['image/jpeg', 'image/jpg', 'image/png'];
    final coverMime = lookupMimeType(albumCover.path);
    final safeCoverMime = supportedPhotoTypes.contains(coverMime)
        ? coverMime!
        : 'image/jpeg';

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $jwtToken'
      ..fields['album_name'] = albumName
      ..files.add(
        await http.MultipartFile.fromPath(
          'album_cover',
          albumCover.path,
          contentType: MediaType.parse(safeCoverMime),
        ),
      );

    try {
      final response = await request.send();
      final responseBody = await http.Response.fromStream(response);

      if (responseBody.statusCode == 201) {
        log.i('[Flutter] Album created successfully: ${responseBody.body}');
        return true;
      } else {
        final cleanMsg = parseApiResponseError(
          responseBody,
          defaultMessage: 'Failed to create album.',
        );
        log.w('[Flutter] Album creation failed: $cleanMsg');
        throw cleanMsg;
      }
    } catch (e, stackTrace) {
      log.e('[Flutter] Error creating album: $e $stackTrace');
      rethrow;
    }
  }

  Map<String, String> _headers(String jwtToken) => {
    'Authorization': 'Bearer $jwtToken',
    'Content-Type': 'application/json',
  };
}

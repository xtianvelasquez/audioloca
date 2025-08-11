import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static final SecureStorageService _instance =
      SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _codeVerifier = 'code_verifier';
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _jwtTokenKey = 'jwt_token';

  Future<void> saveCodeVerifier(String codeVerifier) async {
    await _secureStorage.write(key: _codeVerifier, value: codeVerifier);
  }

  Future<void> saveAccessToken(String token) async {
    await _secureStorage.write(key: _accessTokenKey, value: token);
  }

  Future<void> saveRefreshToken(String token) async {
    await _secureStorage.write(key: _refreshTokenKey, value: token);
  }

  Future<void> saveJwtToken(String token) async {
    await _secureStorage.write(key: _jwtTokenKey, value: token);
  }

  Future<String?> getCodeVerifier() async {
    return await _secureStorage.read(key: _codeVerifier);
  }

  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: _refreshTokenKey);
  }

  Future<String?> getJwtToken() async {
    return await _secureStorage.read(key: _jwtTokenKey);
  }

  Future<void> deleteCodeVerifier() async {
    await _secureStorage.delete(key: _codeVerifier);
  }

  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
  }
}

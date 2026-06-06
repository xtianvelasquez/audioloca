import 'environment.local.dart';

class Environment {
  static const String audiolocaBaseUrl = EnvironmentLocal.audiolocaBaseUrl;

  static const String spotifyClientId = EnvironmentLocal.spotifyClientId;
  static const String spotifyClientSecret =
      EnvironmentLocal.spotifyClientSecret;
  static const String spotifyRedirectUri = EnvironmentLocal.spotifyRedirectUri;

  static const String spotifyApiBase = "https://api.spotify.com/v1";
  static const String spotifyTokenUrl =
      "https://accounts.spotify.com/api/token";

  static const String locationIQAccessToken =
      EnvironmentLocal.locationIQAccessToken;
  static const String locationIQBaseUrl = "https://us1.locationiq.com/v1";
}

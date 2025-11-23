import 'package:flutter/foundation.dart';

enum NowPlayingSource { local, spotify }

class NowPlayingManager {
  static final NowPlayingManager _i = NowPlayingManager._internal();
  factory NowPlayingManager() => _i;
  NowPlayingManager._internal();

  final ValueListenable<NowPlayingSource> listenable =
      ValueNotifier<NowPlayingSource>(NowPlayingSource.local);

  ValueNotifier<NowPlayingSource> get notifier =>
      listenable as ValueNotifier<NowPlayingSource>;

  void useLocal() => notifier.value = NowPlayingSource.local;
  void useSpotify() => notifier.value = NowPlayingSource.spotify;

  void clear() {
    notifier.value = NowPlayingSource.local;
  }
}

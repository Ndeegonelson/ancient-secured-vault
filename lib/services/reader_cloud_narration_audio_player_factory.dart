import 'package:flutter/foundation.dart';

import 'reader_cloud_narration_audio_player.dart';
import 'reader_cloud_narration_provider.dart';
import 'reader_temporary_audio_platform_stub.dart'
    if (dart.library.html) 'reader_temporary_audio_platform_web.dart'
    as platform_factory;
import 'reader_temporary_cloud_narration_audio_player.dart';

ReaderCloudNarrationAudioPlayer createReaderCloudNarrationAudioPlayer() {
  if (!kIsWeb) {
    return ReaderUnsupportedCloudNarrationAudioPlayer();
  }

  return ReaderTemporaryCloudNarrationAudioPlayer(
    platform: platform_factory.createReaderTemporaryAudioPlatform(),
  );
}

class ReaderUnsupportedCloudNarrationAudioPlayer
    implements ReaderCloudNarrationAudioPlayer {
  ValueChanged<String>? _errorHandler;

  static const String unavailableMessage =
      'Cloud narration audio is not available on this platform yet.';

  @override
  void setPositionHandler(ValueChanged<Duration> handler) {}

  @override
  void setCompletionHandler(VoidCallback handler) {}

  @override
  void setErrorHandler(ValueChanged<String> handler) {
    _errorHandler = handler;
  }

  @override
  Future<void> load(ReaderCloudNarrationAudioSegment segment) {
    _errorHandler?.call(unavailableMessage);
    throw UnsupportedError(unavailableMessage);
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

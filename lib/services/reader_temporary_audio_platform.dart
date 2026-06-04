import 'package:flutter/foundation.dart';

abstract interface class ReaderTemporaryAudioPlatform {
  void setPositionHandler(ValueChanged<Duration> handler);

  void setCompletionHandler(VoidCallback handler);

  void setErrorHandler(ValueChanged<String> handler);

  String createObjectUrl(Uint8List audioBytes, String contentType);

  void revokeObjectUrl(String objectUrl);

  Future<void> loadSource(String objectUrl);

  Future<void> clearSource();

  Future<void> play();

  Future<void> pause();

  Future<void> resume();

  Future<void> stop();

  Future<void> dispose();
}

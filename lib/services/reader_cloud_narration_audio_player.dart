import 'package:flutter/foundation.dart';

import 'reader_cloud_narration_provider.dart';

abstract interface class ReaderCloudNarrationAudioPlayer {
  void setPositionHandler(ValueChanged<Duration> handler);

  void setCompletionHandler(VoidCallback handler);

  void setErrorHandler(ValueChanged<String> handler);

  Future<void> load(ReaderCloudNarrationAudioSegment segment);

  Future<void> play();

  Future<void> pause();

  Future<void> resume();

  Future<void> stop();

  Future<void> dispose();
}

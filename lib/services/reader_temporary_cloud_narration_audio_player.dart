import 'dart:async';

import 'package:flutter/foundation.dart';

import 'reader_cloud_narration_audio_player.dart';
import 'reader_cloud_narration_provider.dart';
import 'reader_temporary_audio_platform.dart';

class ReaderTemporaryCloudNarrationAudioPlayer
    implements ReaderCloudNarrationAudioPlayer {
  ReaderTemporaryCloudNarrationAudioPlayer({required this.platform}) {
    platform.setPositionHandler((position) {
      if (!_disposed && _activeObjectUrl != null) {
        _positionHandler?.call(position);
      }
    });
    platform.setCompletionHandler(() {
      if (!_disposed && _activeObjectUrl != null) {
        unawaited(_completeCurrentSegment());
      }
    });
    platform.setErrorHandler((message) {
      if (!_disposed && _activeObjectUrl != null) {
        _errorHandler?.call(message);
      }
    });
  }

  final ReaderTemporaryAudioPlatform platform;

  ValueChanged<Duration>? _positionHandler;
  VoidCallback? _completionHandler;
  ValueChanged<String>? _errorHandler;
  String? _activeObjectUrl;
  int _generation = 0;
  bool _disposed = false;

  bool get hasActiveObjectUrl => _activeObjectUrl != null;

  @override
  void setPositionHandler(ValueChanged<Duration> handler) {
    _positionHandler = handler;
  }

  @override
  void setCompletionHandler(VoidCallback handler) {
    _completionHandler = handler;
  }

  @override
  void setErrorHandler(ValueChanged<String> handler) {
    _errorHandler = handler;
  }

  @override
  Future<void> load(ReaderCloudNarrationAudioSegment segment) async {
    _ensureAvailable();
    if (segment.isEmpty) {
      throw StateError('Cloud narration audio segment is empty.');
    }

    final requestGeneration = ++_generation;
    await _releaseCurrentSource();
    if (_isStale(requestGeneration)) return;

    final objectUrl = platform.createObjectUrl(
      segment.audioBytes,
      segment.contentType,
    );
    _activeObjectUrl = objectUrl;

    try {
      await platform.loadSource(objectUrl);
      if (_isStale(requestGeneration)) {
        await _releaseObjectUrlIfActive(objectUrl);
      }
    } catch (_) {
      await _releaseObjectUrlIfActive(objectUrl);
      rethrow;
    }
  }

  @override
  Future<void> play() async {
    _ensureLoaded();
    await platform.play();
  }

  @override
  Future<void> pause() async {
    _ensureAvailable();
    await platform.pause();
  }

  @override
  Future<void> resume() async {
    _ensureLoaded();
    await platform.resume();
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;

    _generation++;
    try {
      await platform.stop();
    } finally {
      await _releaseCurrentSource(clearPlatformSource: true);
    }
  }

  Future<void> _completeCurrentSegment() async {
    _generation++;
    await _releaseCurrentSource(clearPlatformSource: true);
    if (!_disposed) _completionHandler?.call();
  }

  Future<void> _releaseObjectUrlIfActive(String objectUrl) async {
    if (_activeObjectUrl != objectUrl) return;
    await _releaseCurrentSource(clearPlatformSource: true);
  }

  Future<void> _releaseCurrentSource({bool clearPlatformSource = true}) async {
    final objectUrl = _activeObjectUrl;
    _activeObjectUrl = null;

    if (clearPlatformSource) {
      await platform.clearSource();
    }
    if (objectUrl != null) {
      platform.revokeObjectUrl(objectUrl);
    }
  }

  void _ensureAvailable() {
    if (_disposed) {
      throw StateError('Cloud narration audio player is disposed.');
    }
  }

  void _ensureLoaded() {
    _ensureAvailable();
    if (_activeObjectUrl == null) {
      throw StateError('No protected cloud narration audio is loaded.');
    }
  }

  bool _isStale(int requestGeneration) {
    return _disposed || requestGeneration != _generation;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;

    _disposed = true;
    _generation++;
    try {
      await platform.stop();
    } catch (_) {
      // Disposal must still release temporary audio.
    }
    await _releaseCurrentSource(clearPlatformSource: true);
    await platform.dispose();
  }
}

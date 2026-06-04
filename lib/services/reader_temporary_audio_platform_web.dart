// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

import 'reader_temporary_audio_platform.dart';

ReaderTemporaryAudioPlatform createReaderTemporaryAudioPlatform() {
  return ReaderWebTemporaryAudioPlatform();
}

class ReaderWebTemporaryAudioPlatform implements ReaderTemporaryAudioPlatform {
  ReaderWebTemporaryAudioPlatform() {
    _positionSubscription = _audio.onTimeUpdate.listen((_) {
      _positionHandler?.call(
        Duration(milliseconds: (_audio.currentTime * 1000).round()),
      );
    });
    _completionSubscription = _audio.onEnded.listen((_) {
      _completionHandler?.call();
    });
    _errorSubscription = _audio.onError.listen((_) {
      _errorHandler?.call('Protected cloud narration audio could not play.');
    });
  }

  final html.AudioElement _audio = html.AudioElement()
    ..preload = 'auto'
    ..controls = false;

  ValueChanged<Duration>? _positionHandler;
  VoidCallback? _completionHandler;
  ValueChanged<String>? _errorHandler;
  StreamSubscription<html.Event>? _positionSubscription;
  StreamSubscription<html.Event>? _completionSubscription;
  StreamSubscription<html.Event>? _errorSubscription;

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
  String createObjectUrl(Uint8List audioBytes, String contentType) {
    return html.Url.createObjectUrlFromBlob(
      html.Blob([audioBytes], contentType),
    );
  }

  @override
  void revokeObjectUrl(String objectUrl) {
    html.Url.revokeObjectUrl(objectUrl);
  }

  @override
  Future<void> loadSource(String objectUrl) async {
    _audio.src = objectUrl;
    _audio.load();
  }

  @override
  Future<void> clearSource() async {
    _audio.removeAttribute('src');
    _audio.load();
  }

  @override
  Future<void> play() async {
    await _audio.play();
  }

  @override
  Future<void> pause() async {
    _audio.pause();
  }

  @override
  Future<void> resume() async {
    await _audio.play();
  }

  @override
  Future<void> stop() async {
    _audio.pause();
    _audio.currentTime = 0;
  }

  @override
  Future<void> dispose() async {
    await _positionSubscription?.cancel();
    await _completionSubscription?.cancel();
    await _errorSubscription?.cancel();
    await clearSource();
  }
}

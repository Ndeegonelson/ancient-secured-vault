import 'dart:async';

import 'package:flutter/foundation.dart';

import 'reader_cloud_narration_audio_player.dart';
import 'reader_cloud_narration_preparation_queue.dart';
import 'reader_cloud_narration_provider.dart';
import 'reader_narration_voice.dart';

enum ReaderCloudNarrationPlaybackState {
  idle,
  preparing,
  playing,
  paused,
  stopped,
  completed,
  error,
}

class ReaderCloudNarrationPlaybackController extends ChangeNotifier {
  ReaderCloudNarrationPlaybackController({
    required this.queue,
    required this.audioPlayer,
  }) {
    audioPlayer.setPositionHandler(_handlePosition);
    audioPlayer.setCompletionHandler(_handleSegmentCompletion);
    audioPlayer.setErrorHandler(_handleAudioError);
  }

  final ReaderCloudNarrationPreparationQueue queue;
  final ReaderCloudNarrationAudioPlayer audioPlayer;

  ReaderCloudNarrationPlaybackState _state =
      ReaderCloudNarrationPlaybackState.idle;
  ReaderCloudNarrationPreparedSegment? _activeSegment;
  String? _errorMessage;
  int _documentCharacterCount = 0;
  int _currentCharacterStart = 0;
  int _currentCharacterEnd = 0;
  int _generation = 0;
  bool _disposed = false;

  ReaderCloudNarrationPlaybackState get state => _state;
  ReaderCloudNarrationPreparedSegment? get activeSegment => _activeSegment;
  String? get errorMessage => _errorMessage;
  int get currentCharacterStart => _currentCharacterStart;
  int get currentCharacterEnd => _currentCharacterEnd;
  bool get isPlaying => _state == ReaderCloudNarrationPlaybackState.playing;
  bool get isPaused => _state == ReaderCloudNarrationPlaybackState.paused;
  double get progress {
    if (_documentCharacterCount == 0) return 0;

    return (_currentCharacterEnd / _documentCharacterCount)
        .clamp(0, 1)
        .toDouble();
  }

  int get progressPercent => (progress * 100).round();

  Future<bool> start({
    required String text,
    required ReaderNarrationVoice voice,
    required double rate,
    int startCharacter = 0,
  }) async {
    final requestGeneration = ++_generation;
    queue.cancel();
    _activeSegment = null;
    _state = ReaderCloudNarrationPlaybackState.stopped;
    await audioPlayer.stop();
    if (_isStale(requestGeneration)) return false;

    _documentCharacterCount = text.length;
    _currentCharacterStart = startCharacter.clamp(0, text.length);
    _currentCharacterEnd = _currentCharacterStart;
    _activeSegment = null;
    _errorMessage = null;
    _state = ReaderCloudNarrationPlaybackState.preparing;
    queue.start(
      text: text,
      voice: voice,
      rate: rate,
      startCharacter: startCharacter,
    );
    _notifyListeners();

    await queue.prepareBuffer();
    if (_isStale(requestGeneration)) return false;

    return _playNextPreparedSegment(requestGeneration);
  }

  Future<void> pause() async {
    if (!isPlaying) return;

    try {
      _state = ReaderCloudNarrationPlaybackState.paused;
      _notifyListeners();
      await audioPlayer.pause();
      if (_disposed) return;
    } catch (error) {
      _setError(error.toString());
    }
  }

  Future<void> resume() async {
    if (!isPaused) return;

    try {
      _state = ReaderCloudNarrationPlaybackState.playing;
      _notifyListeners();
      await audioPlayer.resume();
      if (_disposed) return;
    } catch (error) {
      _setError(error.toString());
    }
  }

  Future<void> stop() async {
    _generation++;
    queue.cancel();
    _activeSegment = null;
    _errorMessage = null;
    _state = ReaderCloudNarrationPlaybackState.stopped;
    _notifyListeners();

    try {
      await audioPlayer.stop();
    } catch (_) {
      // Stopping should always release the active narration session.
    }

    if (_disposed) return;

    _notifyListeners();
  }

  Future<bool> _playNextPreparedSegment(int requestGeneration) async {
    if (_isStale(requestGeneration)) return false;

    if (!queue.hasPreparedSegment) {
      await queue.prepareBuffer();
      if (_isStale(requestGeneration)) return false;
    }

    final preparedSegment = queue.takeNext();
    if (preparedSegment == null) {
      if (queue.state == ReaderCloudNarrationPreparationState.error) {
        _setError(
          queue.errorMessage ??
              'Cloud narration could not prepare the next segment.',
        );
        return false;
      }

      _state = ReaderCloudNarrationPlaybackState.completed;
      _currentCharacterStart = _documentCharacterCount;
      _currentCharacterEnd = _documentCharacterCount;
      _activeSegment = null;
      _notifyListeners();
      return true;
    }

    _activeSegment = preparedSegment;
    _currentCharacterStart = preparedSegment.textSegment.startCharacter;
    _currentCharacterEnd = _currentCharacterStart;
    _state = ReaderCloudNarrationPlaybackState.preparing;
    _notifyListeners();

    try {
      await audioPlayer.load(preparedSegment.audioSegment);
      if (_isStale(requestGeneration)) return false;

      await audioPlayer.play();
      if (_isStale(requestGeneration)) return false;

      _state = ReaderCloudNarrationPlaybackState.playing;
      _notifyListeners();
      unawaited(queue.prepareBuffer());
      return true;
    } catch (error) {
      if (!_isStale(requestGeneration)) {
        _setError(error.toString());
      }
      return false;
    }
  }

  void _handlePosition(Duration position) {
    final preparedSegment = _activeSegment;
    if (_disposed ||
        preparedSegment == null ||
        (_state != ReaderCloudNarrationPlaybackState.playing &&
            _state != ReaderCloudNarrationPlaybackState.paused)) {
      return;
    }

    final audioSegment = preparedSegment.audioSegment;
    final cue = _cueAt(audioSegment.timingCues, position);

    if (cue != null) {
      _currentCharacterStart = cue.startCharacter;
      _currentCharacterEnd = cue.endCharacter;
    } else {
      final duration = audioSegment.duration;
      if (duration != null && duration.inMilliseconds > 0) {
        final fraction = (position.inMilliseconds / duration.inMilliseconds)
            .clamp(0, 1);
        final characterCount =
            preparedSegment.textSegment.endCharacter -
            preparedSegment.textSegment.startCharacter;
        _currentCharacterStart =
            preparedSegment.textSegment.startCharacter +
            (characterCount * fraction).floor();
        _currentCharacterEnd = _currentCharacterStart.clamp(
          preparedSegment.textSegment.startCharacter,
          preparedSegment.textSegment.endCharacter,
        );
      }
    }

    _notifyListeners();
  }

  ReaderCloudNarrationTimingCue? _cueAt(
    List<ReaderCloudNarrationTimingCue> cues,
    Duration position,
  ) {
    ReaderCloudNarrationTimingCue? activeCue;

    for (final cue in cues) {
      if (cue.audioOffset > position) break;
      activeCue = cue;
    }

    return activeCue;
  }

  void _handleSegmentCompletion() {
    if (_disposed || _state != ReaderCloudNarrationPlaybackState.playing) {
      return;
    }

    final completedSegment = _activeSegment;
    if (completedSegment != null) {
      _currentCharacterStart = completedSegment.textSegment.endCharacter;
      _currentCharacterEnd = completedSegment.textSegment.endCharacter;
    }
    _activeSegment = null;
    _state = ReaderCloudNarrationPlaybackState.preparing;
    _notifyListeners();

    unawaited(_playNextPreparedSegment(_generation));
  }

  void _handleAudioError(String message) {
    if (_state == ReaderCloudNarrationPlaybackState.idle ||
        _state == ReaderCloudNarrationPlaybackState.stopped ||
        _state == ReaderCloudNarrationPlaybackState.completed) {
      return;
    }

    _setError(message);
  }

  void _setError(String message) {
    if (_disposed) return;

    _generation++;
    queue.cancel();
    _activeSegment = null;
    _errorMessage = message.replaceFirst('Bad state: ', '').trim();
    _state = ReaderCloudNarrationPlaybackState.error;
    _notifyListeners();
  }

  bool _isStale(int requestGeneration) {
    return _disposed || requestGeneration != _generation;
  }

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;

    _disposed = true;
    _generation++;
    queue.cancel();
    unawaited(audioPlayer.dispose());
    super.dispose();
  }
}

import 'reader_cloud_narration_provider.dart';
import 'reader_cloud_narration_registry.dart';
import 'reader_cloud_narration_text_planner.dart';
import 'reader_narration_voice.dart';

enum ReaderCloudNarrationPreparationState {
  idle,
  preparing,
  ready,
  completed,
  cancelled,
  error,
}

class ReaderCloudNarrationPreparedSegment {
  const ReaderCloudNarrationPreparedSegment({
    required this.textSegment,
    required this.audioSegment,
  });

  final ReaderCloudNarrationTextSegment textSegment;
  final ReaderCloudNarrationAudioSegment audioSegment;
}

class ReaderCloudNarrationPreparationQueue {
  ReaderCloudNarrationPreparationQueue({
    required this.registry,
    this.planner = const ReaderCloudNarrationTextPlanner(),
    this.maximumBufferedSegments = 1,
    this.maximumBufferedAudioBytes = 8 * 1024 * 1024,
  }) : assert(maximumBufferedSegments > 0),
       assert(maximumBufferedAudioBytes > 0);

  final ReaderCloudNarrationRegistry registry;
  final ReaderCloudNarrationTextPlanner planner;
  final int maximumBufferedSegments;
  final int maximumBufferedAudioBytes;

  final List<ReaderCloudNarrationPreparedSegment> _buffer = [];
  List<ReaderCloudNarrationTextSegment> _plannedSegments = const [];
  ReaderNarrationVoice? _voice;
  double _rate = 0.5;
  int _nextSegmentIndex = 0;
  int _generation = 0;
  bool _isPreparing = false;
  String? _errorMessage;
  ReaderCloudNarrationPreparationState _state =
      ReaderCloudNarrationPreparationState.idle;

  ReaderCloudNarrationPreparationState get state => _state;
  String? get errorMessage => _errorMessage;
  int get bufferedSegmentCount => _buffer.length;
  int get bufferedAudioByteCount => _buffer.fold(
    0,
    (total, segment) => total + segment.audioSegment.audioBytes.length,
  );
  int get remainingSegmentCount =>
      (_plannedSegments.length - _nextSegmentIndex) + _buffer.length;
  bool get hasPreparedSegment => _buffer.isNotEmpty;
  bool get isPreparing => _isPreparing;

  void start({
    required String text,
    required ReaderNarrationVoice voice,
    required double rate,
    int startCharacter = 0,
  }) {
    _generation++;
    _buffer.clear();
    _plannedSegments = planner.plan(text: text, startCharacter: startCharacter);
    _voice = voice;
    _rate = rate;
    _nextSegmentIndex = 0;
    _isPreparing = false;
    _errorMessage = null;
    _state = _plannedSegments.isEmpty
        ? ReaderCloudNarrationPreparationState.completed
        : ReaderCloudNarrationPreparationState.idle;
  }

  Future<void> prepareBuffer() async {
    if (_isPreparing ||
        _state == ReaderCloudNarrationPreparationState.cancelled ||
        _state == ReaderCloudNarrationPreparationState.completed ||
        _plannedSegments.isEmpty) {
      return;
    }

    final voice = _voice;
    if (voice == null) return;

    final requestGeneration = _generation;
    _isPreparing = true;
    _errorMessage = null;
    _state = ReaderCloudNarrationPreparationState.preparing;

    try {
      while (_buffer.length < maximumBufferedSegments &&
          _nextSegmentIndex < _plannedSegments.length) {
        final textSegment = _plannedSegments[_nextSegmentIndex];
        final request = textSegment.toSynthesisRequest(
          voice: voice,
          rate: _rate,
        );
        final audioSegment = await registry.synthesize(request);

        if (requestGeneration != _generation) return;

        final proposedAudioByteCount =
            bufferedAudioByteCount + audioSegment.audioBytes.length;
        if (proposedAudioByteCount > maximumBufferedAudioBytes) {
          if (_buffer.isEmpty) {
            throw StateError(
              'Cloud narration segment exceeds the secure memory limit.',
            );
          }

          _state = ReaderCloudNarrationPreparationState.ready;
          return;
        }

        _buffer.add(
          ReaderCloudNarrationPreparedSegment(
            textSegment: textSegment,
            audioSegment: audioSegment,
          ),
        );
        _nextSegmentIndex++;
      }

      if (requestGeneration != _generation) return;

      _state = _buffer.isNotEmpty
          ? ReaderCloudNarrationPreparationState.ready
          : ReaderCloudNarrationPreparationState.completed;
    } catch (error) {
      if (requestGeneration != _generation) return;

      _errorMessage = _friendlyErrorMessage(error);
      _state = ReaderCloudNarrationPreparationState.error;
    } finally {
      if (requestGeneration == _generation) {
        _isPreparing = false;
      }
    }
  }

  ReaderCloudNarrationPreparedSegment? takeNext() {
    if (_buffer.isEmpty) {
      if (_nextSegmentIndex >= _plannedSegments.length &&
          _state != ReaderCloudNarrationPreparationState.cancelled) {
        _state = ReaderCloudNarrationPreparationState.completed;
      }
      return null;
    }

    final segment = _buffer.removeAt(0);
    if (_buffer.isEmpty && _nextSegmentIndex >= _plannedSegments.length) {
      _state = ReaderCloudNarrationPreparationState.completed;
    }

    return segment;
  }

  void cancel() {
    _generation++;
    _buffer.clear();
    _plannedSegments = const [];
    _voice = null;
    _nextSegmentIndex = 0;
    _isPreparing = false;
    _errorMessage = null;
    _state = ReaderCloudNarrationPreparationState.cancelled;
  }

  void reset() {
    _generation++;
    _buffer.clear();
    _plannedSegments = const [];
    _voice = null;
    _nextSegmentIndex = 0;
    _isPreparing = false;
    _errorMessage = null;
    _state = ReaderCloudNarrationPreparationState.idle;
  }

  String _friendlyErrorMessage(Object error) {
    final message = error.toString().replaceFirst('Bad state: ', '').trim();
    return message.isEmpty
        ? 'Cloud narration could not prepare the next segment.'
        : message;
  }
}

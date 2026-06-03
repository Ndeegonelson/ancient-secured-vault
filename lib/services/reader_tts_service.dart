import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum ReaderNarrationLanguage {
  english('English', 'en-US'),
  french('French', 'fr-FR');

  const ReaderNarrationLanguage(this.label, this.locale);

  final String label;
  final String locale;
}

enum ReaderNarrationState { idle, playing, paused, stopped, error }

class ReaderTtsService extends ChangeNotifier {
  ReaderTtsService({FlutterTts? flutterTts})
    : _flutterTts = flutterTts ?? FlutterTts() {
    _registerHandlers();
  }

  static const double minimumRate = 0.25;
  static const double maximumRate = 1.0;
  static const double defaultRate = 0.5;

  final FlutterTts _flutterTts;

  ReaderNarrationLanguage _language = ReaderNarrationLanguage.english;
  ReaderNarrationState _state = ReaderNarrationState.idle;
  double _rate = defaultRate;
  String _currentWord = '';
  String _lastText = '';
  int? _pageNumber;
  String? _errorMessage;
  bool _initialized = false;
  bool _disposed = false;

  ReaderNarrationLanguage get language => _language;
  ReaderNarrationState get state => _state;
  double get rate => _rate;
  String get currentWord => _currentWord;
  String get lastText => _lastText;
  int? get pageNumber => _pageNumber;
  String? get errorMessage => _errorMessage;
  bool get isPlaying => _state == ReaderNarrationState.playing;
  bool get isPaused => _state == ReaderNarrationState.paused;

  Future<void> initialize() async {
    if (_initialized) return;

    await _flutterTts.awaitSpeakCompletion(false);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    await _applyLanguage();
    await _applyRate();

    _initialized = true;
  }

  Future<void> setLanguage(ReaderNarrationLanguage language) async {
    if (_language == language) return;

    _language = language;
    _errorMessage = null;
    await initialize();
    await _applyLanguage();
    _notifyListeners();
  }

  Future<void> setRate(double rate) async {
    final safeRate = rate.clamp(minimumRate, maximumRate).toDouble();

    if (_rate == safeRate) return;

    _rate = safeRate;
    _errorMessage = null;
    await initialize();
    await _applyRate();
    _notifyListeners();
  }

  Future<bool> speakPage({
    required String text,
    required int pageNumber,
  }) async {
    final narrationText = text.trim();

    if (narrationText.isEmpty) {
      _setError('No readable text was found on page $pageNumber.');
      return false;
    }

    try {
      await initialize();
      await _flutterTts.stop();

      _lastText = narrationText;
      _pageNumber = pageNumber;
      _currentWord = '';
      _errorMessage = null;

      final result = await _flutterTts.speak(narrationText);
      return result == 1;
    } catch (error) {
      _setError(error.toString());
      return false;
    }
  }

  Future<void> pause() async {
    try {
      await _flutterTts.pause();
    } catch (error) {
      _setError(error.toString());
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _state = ReaderNarrationState.stopped;
      _currentWord = '';
      _errorMessage = null;
      _notifyListeners();
    } catch (error) {
      _setError(error.toString());
    }
  }

  void _registerHandlers() {
    _flutterTts.setStartHandler(() {
      _state = ReaderNarrationState.playing;
      _errorMessage = null;
      _notifyListeners();
    });

    _flutterTts.setCompletionHandler(() {
      _state = ReaderNarrationState.stopped;
      _currentWord = '';
      _notifyListeners();
    });

    _flutterTts.setPauseHandler(() {
      _state = ReaderNarrationState.paused;
      _notifyListeners();
    });

    _flutterTts.setContinueHandler(() {
      _state = ReaderNarrationState.playing;
      _notifyListeners();
    });

    _flutterTts.setCancelHandler(() {
      _state = ReaderNarrationState.stopped;
      _currentWord = '';
      _notifyListeners();
    });

    _flutterTts.setProgressHandler((text, start, end, word) {
      _currentWord = word;
      _notifyListeners();
    });

    _flutterTts.setErrorHandler((message) {
      _setError(message.toString());
    });
  }

  Future<void> _applyLanguage() async {
    await _flutterTts.setLanguage(_language.locale);
  }

  Future<void> _applyRate() async {
    await _flutterTts.setSpeechRate(_rate);
  }

  void _setError(String message) {
    _state = ReaderNarrationState.error;
    _errorMessage = message;
    _notifyListeners();
  }

  void _notifyListeners() {
    if (_disposed) return;

    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _flutterTts.stop();
    super.dispose();
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum ReaderNarrationLanguage {
  english('English', 'en-US'),
  french('French', 'fr-FR');

  const ReaderNarrationLanguage(this.label, this.locale);

  final String label;
  final String locale;

  String get baseLocale => locale.split('-').first;
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
  static const Duration _rateRestartDebounce = Duration(milliseconds: 250);
  static const Duration _stopRestartDelay = Duration(milliseconds: 120);

  final FlutterTts _flutterTts;

  ReaderNarrationLanguage _language = ReaderNarrationLanguage.english;
  ReaderNarrationState _state = ReaderNarrationState.idle;
  double _rate = defaultRate;
  String _currentWord = '';
  String _lastText = '';
  int _currentCharacterEnd = 0;
  int? _pageNumber;
  String? _errorMessage;
  String? _activeLocale;
  List<String> _availableLanguages = [];
  int _restartRequestId = 0;
  bool _initialized = false;
  bool _disposed = false;

  ReaderNarrationLanguage get language => _language;
  ReaderNarrationState get state => _state;
  double get rate => _rate;
  String get currentWord => _currentWord;
  String get lastText => _lastText;
  double get progress {
    if (_lastText.isEmpty) return 0;

    return (_currentCharacterEnd / _lastText.length).clamp(0, 1).toDouble();
  }

  int get progressPercent => (progress * 100).round();
  int? get pageNumber => _pageNumber;
  String? get errorMessage => _errorMessage;
  String? get activeLocale => _activeLocale;
  bool get hasEnglishVoice =>
      _findMatchingLocale(ReaderNarrationLanguage.english) != null;
  bool get hasFrenchVoice =>
      _findMatchingLocale(ReaderNarrationLanguage.french) != null;
  String get detectedVoiceSummary {
    if (_availableLanguages.isEmpty) {
      return 'No browser voices detected';
    }

    final englishStatus = hasEnglishVoice ? 'available' : 'not detected';
    final frenchStatus = hasFrenchVoice ? 'available' : 'not detected';
    return 'English $englishStatus | French $frenchStatus';
  }

  bool get isPlaying => _state == ReaderNarrationState.playing;
  bool get isPaused => _state == ReaderNarrationState.paused;

  Future<void> initialize() async {
    if (_initialized) return;

    await _flutterTts.awaitSpeakCompletion(false);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    await _refreshAvailableLanguages();
    await _applyLanguage();
    await _applyRate();

    _initialized = true;
  }

  Future<void> setLanguage(ReaderNarrationLanguage language) async {
    if (_language == language) return;

    _language = language;
    _errorMessage = null;

    try {
      if (_initialized) {
        await _refreshAvailableLanguages();
        await _applyLanguage();
      } else {
        await initialize();
      }

      _notifyListeners();
      await _restartActiveNarration();
    } catch (error) {
      _setError(_friendlyErrorMessage(error));
    }
  }

  Future<bool> refreshVoices() async {
    _errorMessage = null;

    try {
      await _refreshAvailableLanguages();
      await _applyLanguage();
      _notifyListeners();
      await _restartActiveNarration();
      return true;
    } catch (error) {
      _setError(_friendlyErrorMessage(error));
      return false;
    }
  }

  Future<void> setRate(double rate) async {
    final safeRate = rate.clamp(minimumRate, maximumRate).toDouble();

    if (_rate == safeRate) return;

    _rate = safeRate;
    _errorMessage = null;

    try {
      if (_initialized) {
        await _applyRate();
      } else {
        await initialize();
      }

      _notifyListeners();
      await _restartActiveNarration(debounce: _rateRestartDebounce);
    } catch (error) {
      _setError(_friendlyErrorMessage(error));
    }
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
      if (_initialized) {
        await _refreshAvailableLanguages();
        await _applyLanguage();
        await _applyRate();
      } else {
        await initialize();
      }

      _restartRequestId++;
      await _flutterTts.stop();

      _lastText = narrationText;
      _pageNumber = pageNumber;
      _currentWord = '';
      _currentCharacterEnd = 0;
      _errorMessage = null;

      final result = await _flutterTts.speak(narrationText);
      return result == 1;
    } catch (error) {
      _setError(_friendlyErrorMessage(error));
      return false;
    }
  }

  Future<void> pause() async {
    try {
      _restartRequestId++;
      await _flutterTts.pause();
    } catch (error) {
      _setError(error.toString());
    }
  }

  Future<bool> resume() async {
    if (!isPaused || _lastText.isEmpty) return false;

    try {
      _restartRequestId++;
      _errorMessage = null;
      final result = await _flutterTts.speak(_lastText);
      return result == 1;
    } catch (error) {
      _setError(_friendlyErrorMessage(error));
      return false;
    }
  }

  Future<void> stop() async {
    try {
      _restartRequestId++;
      await _flutterTts.stop();
      _state = ReaderNarrationState.stopped;
      _currentWord = '';
      _currentCharacterEnd = 0;
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
      _currentCharacterEnd = _lastText.length;
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
      _currentCharacterEnd = end.clamp(0, _lastText.length);
      _notifyListeners();
    });

    _flutterTts.setErrorHandler((message) {
      _setError(message.toString());
    });
  }

  Future<void> _applyLanguage() async {
    final matchingLocale = _findMatchingLocale(_language);

    if (_availableLanguages.isNotEmpty && matchingLocale == null) {
      _activeLocale = null;
      throw StateError(
        'No ${_language.label} narration voice is available in this browser.',
      );
    }

    // A base locale such as "fr" lets the web engine select any installed
    // regional French voice when its exact locale list is not ready yet.
    final selectedLocale = matchingLocale ?? _language.baseLocale;
    await _flutterTts.setLanguage(selectedLocale);
    _activeLocale = selectedLocale;
  }

  Future<void> _applyRate() async {
    await _flutterTts.setSpeechRate(_rate);
  }

  Future<void> _refreshAvailableLanguages() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final voiceLanguages = _extractVoiceLanguages(
          await _flutterTts.getVoices,
        );

        if (voiceLanguages.isNotEmpty) {
          _availableLanguages = voiceLanguages;
          return;
        }

        final languageList = _extractLanguageList(
          await _flutterTts.getLanguages,
        );

        if (languageList.isNotEmpty) {
          _availableLanguages = languageList;
          return;
        }
      } catch (_) {
        break;
      }

      if (attempt < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }

    _availableLanguages = [];
  }

  List<String> _extractVoiceLanguages(dynamic voices) {
    if (voices is! List) return [];

    return voices
        .whereType<Map>()
        .map((voice) => voice['locale'])
        .whereType<String>()
        .where((locale) => locale.trim().isNotEmpty)
        .toSet()
        .toList();
  }

  List<String> _extractLanguageList(dynamic languages) {
    if (languages is! List) return [];

    return languages
        .whereType<String>()
        .where((language) => language.trim().isNotEmpty)
        .toSet()
        .toList();
  }

  String? _findMatchingLocale(ReaderNarrationLanguage language) {
    final requestedLocale = language.locale.toLowerCase();
    final baseLocale = language.baseLocale.toLowerCase();

    for (final availableLocale in _availableLanguages) {
      if (availableLocale.toLowerCase() == requestedLocale) {
        return availableLocale;
      }
    }

    for (final availableLocale in _availableLanguages) {
      final normalizedLocale = availableLocale.toLowerCase();
      if (normalizedLocale == baseLocale ||
          normalizedLocale.startsWith('$baseLocale-')) {
        return availableLocale;
      }
    }

    return null;
  }

  Future<void> _restartActiveNarration({
    Duration debounce = Duration.zero,
  }) async {
    if (!isPlaying || _lastText.isEmpty) return;

    final requestId = ++_restartRequestId;

    if (debounce > Duration.zero) {
      await Future<void>.delayed(debounce);
    }

    if (_disposed || requestId != _restartRequestId) return;

    await _flutterTts.stop();
    await Future<void>.delayed(_stopRestartDelay);

    if (_disposed || requestId != _restartRequestId) return;

    _currentWord = '';
    _currentCharacterEnd = 0;
    _errorMessage = null;
    await _flutterTts.speak(_lastText);
  }

  String _friendlyErrorMessage(Object error) {
    if (error is StateError) {
      return error.message.toString();
    }

    return error.toString();
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

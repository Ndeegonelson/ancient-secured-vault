import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'reader_language_detector.dart';
import 'reader_narration_voice.dart';

enum ReaderNarrationLanguage {
  auto('Auto', 'auto'),
  english('English', 'en-US'),
  french('French', 'fr-FR');

  const ReaderNarrationLanguage(this.label, this.locale);

  final String label;
  final String locale;

  String get baseLocale => locale.split('-').first;
}

enum ReaderNarrationState { idle, playing, paused, stopped, error }

class ReaderTtsService extends ChangeNotifier {
  ReaderTtsService({
    FlutterTts? flutterTts,
    ReaderLanguageDetector? languageDetector,
    this.onPageCompleted,
  }) : _flutterTts = flutterTts ?? FlutterTts(),
       _languageDetector = languageDetector ?? const ReaderLanguageDetector() {
    _registerHandlers();
  }

  static const double minimumRate = 0.25;
  static const double maximumRate = 1.0;
  static const double defaultRate = 0.5;
  static const int maximumPassageLength = 220;
  static const Duration _rateRestartDebounce = Duration(milliseconds: 250);
  static const Duration _stopRestartDelay = Duration(milliseconds: 120);

  final FlutterTts _flutterTts;
  final ReaderLanguageDetector _languageDetector;
  final Future<void> Function(int pageNumber)? onPageCompleted;

  ReaderNarrationLanguage _language = ReaderNarrationLanguage.english;
  ReaderNarrationLanguage _effectiveLanguage = ReaderNarrationLanguage.english;
  ReaderTextLanguage _detectedTextLanguage = ReaderTextLanguage.unknown;
  ReaderNarrationState _state = ReaderNarrationState.idle;
  ReaderNarrationState _stateBeforeError = ReaderNarrationState.idle;
  double _rate = defaultRate;
  String _currentWord = '';
  String _currentPassage = '';
  int _currentPassageHighlightStart = 0;
  int _currentPassageHighlightEnd = 0;
  String _lastText = '';
  int _currentCharacterEnd = 0;
  int _speechStartCharacter = 0;
  int? _pageNumber;
  String? _errorMessage;
  String? _activeLocale;
  ReaderNarrationVoice? _activeVoice;
  ReaderNarrationVoice? _selectedVoice;
  String? _preferredVoiceId;
  List<ReaderNarrationVoice> _availableVoices = [];
  List<String> _availableLanguages = [];
  int _restartRequestId = 0;
  DateTime? _ignoreInterruptedErrorsUntil;
  bool _initialized = false;
  bool _disposed = false;
  bool _continueAcrossPages = true;
  bool _continuousPlaybackRequested = false;

  ReaderNarrationLanguage get language => _language;
  ReaderNarrationLanguage get effectiveLanguage => _effectiveLanguage;
  ReaderNarrationState get state => _state;
  double get rate => _rate;
  String get currentWord => _currentWord;
  String get currentPassage => _currentPassage;
  int get currentPassageHighlightStart => _currentPassageHighlightStart;
  int get currentPassageHighlightEnd => _currentPassageHighlightEnd;
  String get lastText => _lastText;
  int get currentCharacterOffset => _currentCharacterEnd;
  double get progress {
    if (_lastText.isEmpty) return 0;

    return (_currentCharacterEnd / _lastText.length).clamp(0, 1).toDouble();
  }

  int get progressPercent => (progress * 100).round();
  int? get pageNumber => _pageNumber;
  String? get errorMessage => _errorMessage;
  String? get activeLocale => _activeLocale;
  ReaderNarrationVoice? get activeVoice => _activeVoice;
  ReaderNarrationVoice? get selectedVoice => _selectedVoice;
  String? get preferredVoiceId => _preferredVoiceId;
  List<ReaderNarrationVoice> get availableBrowserVoices =>
      List.unmodifiable(_availableVoices);
  List<String> get availableBrowserLanguages =>
      List.unmodifiable(_availableLanguages);
  List<ReaderNarrationVoice> get availableVoicesForActiveLanguage {
    return _availableVoices
        .where(
          (voice) => voice.supportsBaseLocale(_effectiveLanguage.baseLocale),
        )
        .toList(growable: false);
  }

  String get automaticLanguageSummary {
    if (_language != ReaderNarrationLanguage.auto) return '';

    if (_detectedTextLanguage == ReaderTextLanguage.unknown) {
      return 'Auto detection pending | English fallback';
    }

    return 'Auto detected: ${_effectiveLanguage.label}';
  }

  bool get hasEnglishVoice =>
      _findMatchingLocale(ReaderNarrationLanguage.english) != null;
  bool get hasFrenchVoice =>
      _findMatchingLocale(ReaderNarrationLanguage.french) != null;
  String get detectedVoiceSummary {
    if (_availableLanguages.isEmpty) {
      return 'No browser voices detected';
    }

    final englishStatus = _voiceCountSummary(ReaderNarrationLanguage.english);
    final frenchStatus = _voiceCountSummary(ReaderNarrationLanguage.french);
    return 'English $englishStatus | French $frenchStatus';
  }

  bool get isPlaying => _state == ReaderNarrationState.playing;
  bool get isPaused => _state == ReaderNarrationState.paused;
  bool get hasResumableProgress =>
      _lastText.isNotEmpty &&
      _currentCharacterEnd > 0 &&
      _currentCharacterEnd < _lastText.length;
  bool canContinueAfterPage(int pageNumber) =>
      _continuousPlaybackRequested && _pageNumber == pageNumber && !_disposed;

  void endContinuousPlayback() {
    _continuousPlaybackRequested = false;
  }

  void restorePreferences({
    required ReaderNarrationLanguage language,
    required double rate,
    String? voiceId,
  }) {
    _language = language;
    _resolveEffectiveLanguage(_lastText);
    _rate = rate.clamp(minimumRate, maximumRate).toDouble();
    _preferredVoiceId = voiceId;
    _errorMessage = null;
    _notifyListeners();
  }

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

    final stateToRecover = _state == ReaderNarrationState.error
        ? _stateBeforeError
        : _state;
    final shouldRestartNarration =
        stateToRecover == ReaderNarrationState.playing;
    _language = language;
    _resolveEffectiveLanguage(_lastText);
    _errorMessage = null;
    _state = stateToRecover;
    _notifyListeners();

    try {
      if (_initialized) {
        await _refreshAvailableLanguages();
        await _applyLanguage();
      } else {
        await initialize();
      }

      _notifyListeners();
      if (shouldRestartNarration) {
        await _restartActiveNarration();
      }
    } catch (error) {
      _setError(_friendlyErrorMessage(error));
    }
  }

  Future<bool> refreshVoices() async {
    _errorMessage = null;

    try {
      await _refreshAvailableLanguages(waitForAdditionalVoices: true);
      await _applyLanguage();
      _notifyListeners();
      await _restartActiveNarration();
      return true;
    } catch (error) {
      _setError(_friendlyErrorMessage(error));
      return false;
    }
  }

  Future<void> setVoice(ReaderNarrationVoice voice) async {
    final availableVoice = _availableVoices.where(
      (item) => item.id == voice.id,
    );
    if (availableVoice.isEmpty ||
        !voice.supportsBaseLocale(_effectiveLanguage.baseLocale)) {
      return;
    }

    _selectedVoice = availableVoice.first;
    _preferredVoiceId = _selectedVoice!.id;
    _errorMessage = null;

    try {
      await _applyLanguage();
      _notifyListeners();
      await _restartActiveNarration();
    } catch (error) {
      _setError(_friendlyErrorMessage(error));
    }
  }

  Future<void> useAssignedVoice() async {
    if (_selectedVoice == null && _preferredVoiceId == null) return;

    _selectedVoice = null;
    _preferredVoiceId = null;
    _errorMessage = null;

    try {
      if (_initialized) {
        await _applyLanguage();
      }
      _notifyListeners();
      await _restartActiveNarration();
    } catch (error) {
      _setError(_friendlyErrorMessage(error));
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
    int startCharacter = 0,
    bool continueAcrossPages = true,
  }) async {
    final narrationText = text.trim();

    if (narrationText.isEmpty) {
      _setError('No readable text was found on page $pageNumber.');
      return false;
    }

    try {
      final requestId = ++_restartRequestId;
      _resolveEffectiveLanguage(narrationText);

      if (_initialized) {
        await _refreshAvailableLanguages();
        await _applyLanguage();
        await _applyRate();
      } else {
        await initialize();
      }

      if (_disposed || requestId != _restartRequestId) return false;

      await _stopForReplacement();

      if (_disposed || requestId != _restartRequestId) return false;

      _lastText = narrationText;
      _pageNumber = pageNumber;
      _continueAcrossPages = continueAcrossPages;
      _continuousPlaybackRequested = continueAcrossPages;
      _currentWord = '';
      _speechStartCharacter = startCharacter >= narrationText.length
          ? 0
          : startCharacter.clamp(0, narrationText.length - 1);
      _currentCharacterEnd = _speechStartCharacter;
      _updateCurrentPassage(
        narrationText,
        _speechStartCharacter,
        _speechStartCharacter + 1,
      );
      _errorMessage = null;

      final result = await _flutterTts.speak(
        narrationText.substring(_speechStartCharacter),
      );
      return result == 1;
    } catch (error) {
      _setError(_friendlyErrorMessage(error));
      return false;
    }
  }

  Future<void> pause() async {
    try {
      _restartRequestId++;
      _continuousPlaybackRequested = false;
      await _flutterTts.pause();
    } catch (error) {
      _setError(error.toString());
    }
  }

  Future<bool> resume() async {
    if (!isPaused || _lastText.isEmpty) return false;

    try {
      _restartRequestId++;
      _continuousPlaybackRequested = _continueAcrossPages;
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
      _continuousPlaybackRequested = false;
      _ignoreInterruptedErrorsUntil = DateTime.now().add(
        const Duration(seconds: 1),
      );
      await _flutterTts.stop();
      _state = ReaderNarrationState.stopped;
      _currentWord = '';
      _currentPassage = '';
      _clearCurrentPassageHighlight();
      _currentCharacterEnd = 0;
      _speechStartCharacter = 0;
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
      final completedPage = _pageNumber;
      _state = ReaderNarrationState.stopped;
      _currentWord = '';
      _clearCurrentPassageHighlight();
      _currentCharacterEnd = _lastText.length;
      _notifyListeners();

      if (completedPage != null && _continuousPlaybackRequested) {
        onPageCompleted?.call(completedPage);
      }
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
      _clearCurrentPassageHighlight();
      _notifyListeners();
    });

    _flutterTts.setProgressHandler((text, start, end, word) {
      _currentWord = word;
      final absoluteStart = (_speechStartCharacter + start).clamp(
        0,
        _lastText.length,
      );
      final absoluteEnd = (_speechStartCharacter + end).clamp(
        0,
        _lastText.length,
      );
      _currentCharacterEnd = absoluteEnd;
      _updateCurrentPassage(
        _lastText,
        absoluteStart,
        absoluteEnd,
        highlightWord: word,
      );
      _notifyListeners();
    });

    _flutterTts.setErrorHandler((message) {
      final errorMessage = message.toString();

      if (_shouldIgnoreInterruptedError(errorMessage)) return;

      _setError(errorMessage);
    });
  }

  Future<void> _applyLanguage() async {
    final matchingLocale = _findMatchingLocale(_effectiveLanguage);

    if (_availableLanguages.isNotEmpty && matchingLocale == null) {
      _activeLocale = null;
      final unavailableMessage = _language == ReaderNarrationLanguage.auto
          ? 'Auto detected ${_effectiveLanguage.label}, but no '
                '${_effectiveLanguage.label} narration voice is available '
                'in this browser.'
          : 'No ${_effectiveLanguage.label} narration voice is available '
                'in this browser.';
      throw StateError(unavailableMessage);
    }

    // A base locale such as "fr" lets the web engine select any installed
    // regional French voice when its exact locale list is not ready yet.
    final selectedLocale = matchingLocale ?? _effectiveLanguage.baseLocale;
    await _flutterTts.setLanguage(selectedLocale);
    _activeLocale = selectedLocale;

    final matchingVoices = availableVoicesForActiveLanguage;
    final selectedVoice = _selectedVoice;
    final preferredVoices = matchingVoices.where(
      (voice) => voice.id == _preferredVoiceId,
    );
    final voiceToApply =
        selectedVoice != null &&
            matchingVoices.any((voice) => voice.id == selectedVoice.id)
        ? selectedVoice
        : preferredVoices.isNotEmpty
        ? preferredVoices.first
        : matchingVoices.isEmpty
        ? null
        : matchingVoices.first;

    if (voiceToApply != null) {
      await _flutterTts.setVoice(voiceToApply.browserVoice);
      _activeVoice = voiceToApply;
      if (voiceToApply.id == _preferredVoiceId) {
        _selectedVoice = voiceToApply;
      }
      _activeLocale = voiceToApply.locale;
    } else {
      _activeVoice = null;
    }
  }

  void _resolveEffectiveLanguage(String text) {
    if (_language != ReaderNarrationLanguage.auto) {
      _effectiveLanguage = _language;
      _detectedTextLanguage = ReaderTextLanguage.unknown;
      return;
    }

    _detectedTextLanguage = _languageDetector.detect(text);
    _effectiveLanguage = switch (_detectedTextLanguage) {
      ReaderTextLanguage.french => ReaderNarrationLanguage.french,
      ReaderTextLanguage.english => ReaderNarrationLanguage.english,
      ReaderTextLanguage.unknown => ReaderNarrationLanguage.english,
    };
  }

  Future<void> _applyRate() async {
    await _flutterTts.setSpeechRate(_rate);
  }

  Future<void> _refreshAvailableLanguages({
    bool waitForAdditionalVoices = false,
  }) async {
    final maximumAttempts = waitForAdditionalVoices ? 6 : 3;
    var richestVoiceCatalog = <ReaderNarrationVoice>[];
    var richestLanguageCatalog = <String>[];

    for (var attempt = 0; attempt < maximumAttempts; attempt++) {
      try {
        final voices = _extractVoices(await _flutterTts.getVoices);
        final voiceLanguages = voices.map((voice) => voice.locale).toList();

        if (voices.length > richestVoiceCatalog.length) {
          richestVoiceCatalog = voices;
        }
        if (voiceLanguages.length > richestLanguageCatalog.length) {
          richestLanguageCatalog = voiceLanguages;
        }

        if (!waitForAdditionalVoices && voiceLanguages.isNotEmpty) {
          break;
        }

        if (voiceLanguages.isEmpty) {
          final languageList = _extractLanguageList(
            await _flutterTts.getLanguages,
          );

          if (languageList.length > richestLanguageCatalog.length) {
            richestLanguageCatalog = languageList;
          }
          if (!waitForAdditionalVoices && languageList.isNotEmpty) {
            break;
          }
        }
      } catch (_) {
        break;
      }

      if (attempt < maximumAttempts - 1) {
        await Future<void>.delayed(
          Duration(milliseconds: waitForAdditionalVoices ? 400 : 100),
        );
      }
    }

    _availableVoices = richestVoiceCatalog;
    _availableLanguages = richestVoiceCatalog.isNotEmpty
        ? richestVoiceCatalog.map((voice) => voice.locale).toList()
        : richestLanguageCatalog;
  }

  List<ReaderNarrationVoice> _extractVoices(dynamic voices) {
    if (voices is! List) return [];

    return voices
        .whereType<Map>()
        .map(ReaderNarrationVoice.fromMap)
        .where((voice) => voice.name.isNotEmpty && voice.locale.isNotEmpty)
        .fold<Map<String, ReaderNarrationVoice>>({}, (voicesById, voice) {
          voicesById[voice.id] = voice;
          return voicesById;
        })
        .values
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

  String _voiceCountSummary(ReaderNarrationLanguage language) {
    final count = _availableVoices
        .where((voice) => voice.supportsBaseLocale(language.baseLocale))
        .length;

    if (count == 0) {
      return _findMatchingLocale(language) == null
          ? 'not detected'
          : 'available';
    }

    return count == 1 ? '1 voice' : '$count voices';
  }

  Future<void> _restartActiveNarration({
    Duration debounce = Duration.zero,
  }) async {
    if (!isPlaying || _lastText.isEmpty) return;

    final requestId = ++_restartRequestId;
    _continuousPlaybackRequested = _continueAcrossPages;

    if (debounce > Duration.zero) {
      await Future<void>.delayed(debounce);
    }

    if (_disposed || requestId != _restartRequestId) return;

    await _stopForReplacement();

    if (_disposed || requestId != _restartRequestId) return;

    final restartOffset = _currentCharacterEnd.clamp(0, _lastText.length - 1);
    _currentWord = '';
    _updateCurrentPassage(_lastText, restartOffset, restartOffset + 1);
    _currentCharacterEnd = restartOffset;
    _speechStartCharacter = restartOffset;
    _errorMessage = null;
    await _flutterTts.speak(_lastText.substring(restartOffset));
  }

  Future<void> _stopForReplacement() async {
    _ignoreInterruptedErrorsUntil = DateTime.now().add(
      const Duration(seconds: 1),
    );
    await _flutterTts.stop();
    await Future<void>.delayed(_stopRestartDelay);
  }

  bool _shouldIgnoreInterruptedError(String message) {
    final ignoreUntil = _ignoreInterruptedErrorsUntil;
    final normalizedMessage = message.trim().toLowerCase();
    final isExpectedCancellation =
        normalizedMessage == 'interrupted' ||
        normalizedMessage == 'canceled' ||
        normalizedMessage == 'cancelled';

    return isExpectedCancellation &&
        ignoreUntil != null &&
        DateTime.now().isBefore(ignoreUntil);
  }

  void _updateCurrentPassage(
    String text,
    int start,
    int end, {
    String highlightWord = '',
  }) {
    final selection = _passageForRange(text, start, end);
    _currentPassage = selection.text;
    _clearCurrentPassageHighlight();

    final word = highlightWord.trim();
    if (word.isEmpty || selection.text.isEmpty) return;

    final safeStart = start.clamp(selection.sourceStart, selection.sourceEnd);
    final sourcePrefix = _cleanPassage(
      text.substring(selection.sourceStart, safeStart),
    );
    final expectedStart =
        sourcePrefix.length + (selection.hasLeadingEllipsis ? 4 : 0);
    final passage = selection.text.toLowerCase();
    final target = word.toLowerCase();
    var bestStart = -1;
    var bestDistance = selection.text.length + 1;
    var matchStart = passage.indexOf(target);

    while (matchStart >= 0) {
      final distance = (matchStart - expectedStart).abs();
      if (distance < bestDistance) {
        bestStart = matchStart;
        bestDistance = distance;
      }
      matchStart = passage.indexOf(target, matchStart + 1);
    }

    if (bestStart < 0) return;

    _currentPassageHighlightStart = bestStart;
    _currentPassageHighlightEnd = bestStart + word.length;
  }

  void _clearCurrentPassageHighlight() {
    _currentPassageHighlightStart = 0;
    _currentPassageHighlightEnd = 0;
  }

  _NarrationPassage _passageForRange(String text, int start, int end) {
    if (text.isEmpty) return const _NarrationPassage.empty();

    final safeStart = start.clamp(0, text.length - 1);
    final safeEnd = end.clamp(safeStart + 1, text.length);
    var passageStart = _previousBoundary(text, safeStart, const {
      '.',
      '!',
      '?',
      '\n',
    });
    var passageEnd = _nextBoundary(text, safeEnd, const {'.', '!', '?', '\n'});
    var passage = _cleanPassage(text.substring(passageStart, passageEnd));

    if (passage.length <= maximumPassageLength) {
      return _NarrationPassage(
        text: passage,
        sourceStart: passageStart,
        sourceEnd: passageEnd,
      );
    }

    passageStart = _previousBoundary(text, safeStart, const {
      ',',
      ';',
      ':',
      '\n',
    }, minimum: passageStart);
    passageEnd = _nextBoundary(text, safeEnd, const {
      ',',
      ';',
      ':',
      '\n',
    }, maximum: passageEnd);
    passage = _cleanPassage(text.substring(passageStart, passageEnd));

    if (passage.length <= maximumPassageLength) {
      return _NarrationPassage(
        text: passage,
        sourceStart: passageStart,
        sourceEnd: passageEnd,
      );
    }

    final windowStart = (safeStart - 85).clamp(0, text.length);
    final windowEnd = (safeEnd + 125).clamp(0, text.length);
    final prefix = windowStart > 0 ? '... ' : '';
    final suffix = windowEnd < text.length ? ' ...' : '';

    return _NarrationPassage(
      text:
          '$prefix${_cleanPassage(text.substring(windowStart, windowEnd))}$suffix',
      sourceStart: windowStart,
      sourceEnd: windowEnd,
      hasLeadingEllipsis: prefix.isNotEmpty,
    );
  }

  int _previousBoundary(
    String text,
    int from,
    Set<String> boundaries, {
    int minimum = 0,
  }) {
    for (var index = from - 1; index >= minimum; index--) {
      if (boundaries.contains(text[index])) {
        return (index + 1).clamp(minimum, text.length);
      }
    }

    return minimum;
  }

  int _nextBoundary(
    String text,
    int from,
    Set<String> boundaries, {
    int? maximum,
  }) {
    final safeMaximum = maximum ?? text.length;

    for (var index = from; index < safeMaximum; index++) {
      if (boundaries.contains(text[index])) {
        return (index + 1).clamp(0, safeMaximum);
      }
    }

    return safeMaximum;
  }

  String _cleanPassage(String passage) {
    return passage.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _friendlyErrorMessage(Object error) {
    if (error is StateError) {
      return error.message.toString();
    }

    return error.toString();
  }

  void _setError(String message) {
    if (_state != ReaderNarrationState.error) {
      _stateBeforeError = _state;
    }
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

class _NarrationPassage {
  const _NarrationPassage({
    required this.text,
    required this.sourceStart,
    required this.sourceEnd,
    this.hasLeadingEllipsis = false,
  });

  const _NarrationPassage.empty()
    : text = '',
      sourceStart = 0,
      sourceEnd = 0,
      hasLeadingEllipsis = false;

  final String text;
  final int sourceStart;
  final int sourceEnd;
  final bool hasLeadingEllipsis;
}

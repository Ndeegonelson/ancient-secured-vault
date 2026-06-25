import 'package:ancient_secure_docs/services/reader_tts_service.dart';
import 'package:ancient_secure_docs/services/reader_narration_voice.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

class FakeFlutterTts extends FlutterTts {
  FakeFlutterTts({
    this.availableLanguages = const ['en-US', 'fr-FR'],
    List<String>? availableVoiceLanguages,
    this.availableVoices,
    this.voiceSnapshots,
  }) : availableVoiceLanguages =
           availableVoiceLanguages ?? List.of(availableLanguages);

  final List<String> availableLanguages;
  final List<String> availableVoiceLanguages;
  final List<Map<String, String>>? availableVoices;
  final List<List<Map<String, String>>>? voiceSnapshots;
  int voiceRequestCount = 0;
  String? selectedLanguage;
  Map<String, String>? selectedVoice;
  double? selectedRate;
  String? spokenText;
  int speakCount = 0;
  int stopCount = 0;
  VoidCallback? startCallback;
  VoidCallback? pauseCallback;
  VoidCallback? continueCallback;
  VoidCallback? completionCallback;
  VoidCallback? cancelCallback;
  ProgressHandler? progressCallback;
  ErrorHandler? errorCallback;

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async => 1;

  @override
  Future<dynamic> setVolume(double volume) async => 1;

  @override
  Future<dynamic> setPitch(double pitch) async => 1;

  @override
  Future<dynamic> get getLanguages async => availableLanguages;

  @override
  Future<dynamic> get getVoices async {
    final snapshots = voiceSnapshots;
    if (snapshots != null && snapshots.isNotEmpty) {
      final index = voiceRequestCount.clamp(0, snapshots.length - 1);
      voiceRequestCount++;
      return snapshots[index];
    }

    return availableVoices ??
        availableVoiceLanguages
            .map((locale) => {'name': 'Voice $locale', 'locale': locale})
            .toList();
  }

  @override
  Future<dynamic> setLanguage(String language) async {
    selectedLanguage = language;
    return 1;
  }

  @override
  Future<dynamic> setVoice(Map<String, String> voice) async {
    selectedVoice = voice;
    return 1;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async {
    selectedRate = rate;
    return 1;
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    spokenText = text;
    speakCount++;
    startCallback?.call();
    return 1;
  }

  @override
  Future<dynamic> stop() async {
    stopCount++;
    cancelCallback?.call();
    return 1;
  }

  @override
  Future<dynamic> pause() async {
    pauseCallback?.call();
    return 1;
  }

  @override
  void setStartHandler(VoidCallback callback) {
    startCallback = callback;
  }

  @override
  void setPauseHandler(VoidCallback callback) {
    pauseCallback = callback;
  }

  @override
  void setContinueHandler(VoidCallback callback) {
    continueCallback = callback;
  }

  @override
  void setCompletionHandler(VoidCallback callback) {
    completionCallback = callback;
  }

  @override
  void setCancelHandler(VoidCallback callback) {
    cancelCallback = callback;
  }

  @override
  void setProgressHandler(ProgressHandler callback) {
    progressCallback = callback;
  }

  @override
  void setErrorHandler(ErrorHandler callback) {
    errorCallback = callback;
  }

  void reportProgress(String text, int start, int end, String word) {
    progressCallback?.call(text, start, end, word);
  }

  void reportError(String message) {
    errorCallback?.call(message);
  }

  void completeSpeech() {
    completionCallback?.call();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('initializes with English and the default narration rate', () async {
    final fakeTts = FakeFlutterTts();
    final service = ReaderTtsService(flutterTts: fakeTts);

    await service.initialize();

    expect(fakeTts.selectedLanguage, 'en-US');
    expect(fakeTts.selectedRate, ReaderTtsService.defaultRate);
    expect(service.language, ReaderNarrationLanguage.english);
    expect(service.activeLocale, 'en-US');

    service.dispose();
  });

  test('supports French and clamps narration speed', () async {
    final fakeTts = FakeFlutterTts();
    final service = ReaderTtsService(flutterTts: fakeTts);

    await service.setLanguage(ReaderNarrationLanguage.french);
    await service.setRate(5);

    expect(fakeTts.selectedLanguage, 'fr-FR');
    expect(service.rate, ReaderTtsService.maximumRate);
    expect(fakeTts.selectedRate, ReaderTtsService.maximumRate);

    service.dispose();
  });

  test('exposes and applies a compatible selected narrator voice', () async {
    final fakeTts = FakeFlutterTts(
      availableVoices: const [
        {'name': 'English One', 'locale': 'en-US'},
        {'name': 'English Two', 'locale': 'en-GB', 'gender': 'Female'},
        {'name': 'French One', 'locale': 'fr-FR'},
      ],
    );
    final service = ReaderTtsService(flutterTts: fakeTts);

    await service.initialize();

    expect(service.availableVoicesForActiveLanguage, hasLength(2));
    expect(service.availableBrowserVoices, hasLength(3));
    expect(service.availableBrowserLanguages, ['en-US', 'en-GB', 'fr-FR']);

    const voice = ReaderNarrationVoice(
      name: 'English Two',
      locale: 'en-GB',
      gender: 'Female',
    );
    await service.setVoice(voice);

    expect(service.selectedVoice?.id, voice.id);
    expect(service.preferredVoiceId, voice.id);
    expect(service.activeVoice?.id, voice.id);
    expect(fakeTts.selectedVoice, voice.browserVoice);

    service.dispose();
  });

  test(
    'restores a saved narrator voice when voices become available',
    () async {
      final fakeTts = FakeFlutterTts(
        availableVoices: const [
          {'name': 'English One', 'locale': 'en-US'},
          {'name': 'English Two', 'locale': 'en-GB'},
        ],
      );
      final service = ReaderTtsService(flutterTts: fakeTts);

      service.restorePreferences(
        language: ReaderNarrationLanguage.english,
        rate: 0.75,
        voiceId: 'browser|en-GB|English Two',
      );
      await service.initialize();

      expect(service.selectedVoice?.name, 'English Two');
      expect(service.activeVoice?.name, 'English Two');
      expect(fakeTts.selectedVoice, {'name': 'English Two', 'locale': 'en-GB'});

      service.dispose();
    },
  );

  test('browser voice snapshots cannot mutate internal voice state', () async {
    final fakeTts = FakeFlutterTts(
      availableVoices: const [
        {'name': 'English One', 'locale': 'en-US'},
      ],
    );
    final service = ReaderTtsService(flutterTts: fakeTts);

    await service.initialize();

    expect(
      () => service.availableBrowserVoices.add(
        const ReaderNarrationVoice(name: 'Injected', locale: 'en-US'),
      ),
      throwsUnsupportedError,
    );
    expect(
      () => service.availableBrowserLanguages.add('fr-FR'),
      throwsUnsupportedError,
    );
    expect(service.availableBrowserVoices, hasLength(1));
    expect(service.availableBrowserLanguages, ['en-US']);

    service.dispose();
  });

  test('returns a former subscriber to the assigned narrator', () async {
    final fakeTts = FakeFlutterTts(
      availableVoices: const [
        {'name': 'Assigned Voice', 'locale': 'en-US'},
        {'name': 'Premium Voice', 'locale': 'en-GB'},
      ],
    );
    final service = ReaderTtsService(flutterTts: fakeTts);

    await service.initialize();
    await service.setVoice(
      const ReaderNarrationVoice(name: 'Premium Voice', locale: 'en-GB'),
    );
    await service.useAssignedVoice();

    expect(service.selectedVoice, isNull);
    expect(service.activeVoice?.name, 'Assigned Voice');
    expect(fakeTts.selectedVoice, {
      'name': 'Assigned Voice',
      'locale': 'en-US',
    });

    service.dispose();
  });

  test('manual refresh keeps the richest delayed browser voice list', () async {
    final fakeTts = FakeFlutterTts(
      voiceSnapshots: const [
        [
          {'name': 'Microsoft David', 'locale': 'en-US'},
        ],
        [
          {'name': 'Microsoft David', 'locale': 'en-US'},
          {'name': 'Microsoft Zira', 'locale': 'en-US'},
        ],
      ],
    );
    final service = ReaderTtsService(flutterTts: fakeTts);

    await service.initialize();
    expect(service.availableVoicesForActiveLanguage, hasLength(1));

    await service.refreshVoices();

    expect(service.availableVoicesForActiveLanguage, hasLength(2));
    expect(
      service.detectedVoiceSummary,
      'English 2 voices | French not detected',
    );

    service.dispose();
  });

  test('restores saved preferences without starting narration', () {
    final fakeTts = FakeFlutterTts(availableLanguages: const ['en-US']);
    final service = ReaderTtsService(flutterTts: fakeTts);

    service.restorePreferences(
      language: ReaderNarrationLanguage.french,
      rate: 0.75,
    );

    expect(service.language, ReaderNarrationLanguage.french);
    expect(service.rate, 0.75);
    expect(service.state, ReaderNarrationState.idle);
    expect(service.errorMessage, isNull);
    expect(fakeTts.selectedLanguage, isNull);
    expect(fakeTts.speakCount, 0);

    service.dispose();
  });

  test('clamps an invalid saved narration speed during restore', () {
    final service = ReaderTtsService(flutterTts: FakeFlutterTts());

    service.restorePreferences(language: ReaderNarrationLanguage.auto, rate: 5);

    expect(service.language, ReaderNarrationLanguage.auto);
    expect(service.rate, ReaderTtsService.maximumRate);

    service.dispose();
  });

  test('Auto selects an English voice for English text', () async {
    final fakeTts = FakeFlutterTts(
      availableLanguages: const ['en-US', 'fr-FR'],
    );
    final service = ReaderTtsService(flutterTts: fakeTts);

    await service.setLanguage(ReaderNarrationLanguage.auto);
    await service.speakPage(
      text: 'The reader is learning from the document and its history.',
      pageNumber: 7,
    );

    expect(service.language, ReaderNarrationLanguage.auto);
    expect(service.effectiveLanguage, ReaderNarrationLanguage.english);
    expect(service.automaticLanguageSummary, 'Auto detected: English');
    expect(fakeTts.selectedLanguage, 'en-US');

    service.dispose();
  });

  test('Auto selects a French voice for French text', () async {
    final fakeTts = FakeFlutterTts(
      availableLanguages: const ['en-US', 'fr-FR'],
    );
    final service = ReaderTtsService(flutterTts: fakeTts);

    await service.setLanguage(ReaderNarrationLanguage.auto);
    await service.speakPage(
      text: 'Le document explique comment le système fonctionne pour tous.',
      pageNumber: 7,
    );

    expect(service.language, ReaderNarrationLanguage.auto);
    expect(service.effectiveLanguage, ReaderNarrationLanguage.french);
    expect(service.automaticLanguageSummary, 'Auto detected: French');
    expect(fakeTts.selectedLanguage, 'fr-FR');

    service.dispose();
  });

  test('Auto detects the language again when narration changes page', () async {
    final fakeTts = FakeFlutterTts(
      availableLanguages: const ['en-US', 'fr-FR'],
    );
    final service = ReaderTtsService(flutterTts: fakeTts);

    await service.setLanguage(ReaderNarrationLanguage.auto);
    await service.speakPage(
      text: 'The reader is learning from the document and its history.',
      pageNumber: 7,
    );
    expect(fakeTts.selectedLanguage, 'en-US');

    await service.speakPage(
      text: 'Le document explique comment le système fonctionne pour tous.',
      pageNumber: 8,
    );

    expect(service.effectiveLanguage, ReaderNarrationLanguage.french);
    expect(fakeTts.selectedLanguage, 'fr-FR');

    service.dispose();
  });

  test('Auto clearly reports when its detected voice is unavailable', () async {
    final fakeTts = FakeFlutterTts(availableLanguages: const ['en-US']);
    final service = ReaderTtsService(flutterTts: fakeTts);

    await service.setLanguage(ReaderNarrationLanguage.auto);
    final started = await service.speakPage(
      text: 'Le document explique comment le système fonctionne pour tous.',
      pageNumber: 7,
    );

    expect(started, isFalse);
    expect(service.effectiveLanguage, ReaderNarrationLanguage.french);
    expect(
      service.errorMessage,
      'Auto detected French, but no French narration voice is available '
      'in this browser.',
    );

    service.dispose();
  });

  test(
    'Auto recovers active narration after an unavailable French voice',
    () async {
      final fakeTts = FakeFlutterTts(availableLanguages: const ['en-US']);
      final service = ReaderTtsService(flutterTts: fakeTts);

      await service.speakPage(
        text: 'The reader is learning from the document and its history.',
        pageNumber: 7,
      );
      fakeTts.reportProgress(service.lastText, 11, 19, 'learning');
      await service.setLanguage(ReaderNarrationLanguage.french);

      expect(service.state, ReaderNarrationState.error);

      await service.setLanguage(ReaderNarrationLanguage.auto);

      expect(service.language, ReaderNarrationLanguage.auto);
      expect(service.effectiveLanguage, ReaderNarrationLanguage.english);
      expect(service.errorMessage, isNull);
      expect(fakeTts.selectedLanguage, 'en-US');
      expect(fakeTts.spokenText, service.lastText.substring(19));

      service.dispose();
    },
  );

  test('uses an available regional French voice as a fallback', () async {
    final fakeTts = FakeFlutterTts(
      availableLanguages: const ['en-US', 'fr-CA'],
    );
    final service = ReaderTtsService(flutterTts: fakeTts);

    await service.setLanguage(ReaderNarrationLanguage.french);

    expect(fakeTts.selectedLanguage, 'fr-CA');
    expect(service.activeLocale, 'fr-CA');

    service.dispose();
  });

  test('reports when the browser has no French narration voice', () async {
    final fakeTts = FakeFlutterTts(availableLanguages: const ['en-US']);
    final service = ReaderTtsService(flutterTts: fakeTts);

    await service.setLanguage(ReaderNarrationLanguage.french);

    expect(service.state, ReaderNarrationState.error);
    expect(service.language, ReaderNarrationLanguage.french);
    expect(service.activeLocale, isNull);
    expect(service.hasEnglishVoice, isTrue);
    expect(service.hasFrenchVoice, isFalse);
    expect(
      service.detectedVoiceSummary,
      'English 1 voice | French not detected',
    );
    expect(
      service.errorMessage,
      'No French narration voice is available in this browser.',
    );

    service.dispose();
  });

  test(
    'refreshes the live browser voice list after installing French',
    () async {
      final liveVoices = <String>['en-US'];
      final fakeTts = FakeFlutterTts(
        availableLanguages: const ['en-US'],
        availableVoiceLanguages: liveVoices,
      );
      final service = ReaderTtsService(flutterTts: fakeTts);

      await service.setLanguage(ReaderNarrationLanguage.french);
      liveVoices.add('fr-FR');
      final refreshed = await service.refreshVoices();

      expect(refreshed, isTrue);
      expect(service.language, ReaderNarrationLanguage.french);
      expect(service.activeLocale, 'fr-FR');
      expect(service.errorMessage, isNull);

      service.dispose();
    },
  );

  test('stores page context when speaking extracted PDF text', () async {
    final fakeTts = FakeFlutterTts();
    final service = ReaderTtsService(flutterTts: fakeTts);

    final started = await service.speakPage(
      text: '  Protected learning text.  ',
      pageNumber: 7,
    );

    expect(started, isTrue);
    expect(fakeTts.spokenText, 'Protected learning text.');
    expect(service.lastText, 'Protected learning text.');
    expect(service.pageNumber, 7);

    service.dispose();
  });

  test('applies speed changes without restarting active narration', () async {
    final fakeTts = FakeFlutterTts();
    final service = ReaderTtsService(flutterTts: fakeTts);

    await service.speakPage(text: 'Protected learning text.', pageNumber: 7);
    await service.setRate(0.75);

    expect(fakeTts.selectedRate, 0.75);
    expect(fakeTts.speakCount, 1);
    expect(fakeTts.spokenText, 'Protected learning text.');

    service.dispose();
  });

  test('tracks narration progress from spoken character positions', () async {
    final fakeTts = FakeFlutterTts();
    final service = ReaderTtsService(flutterTts: fakeTts);

    await service.speakPage(text: '1234567890', pageNumber: 7);
    fakeTts.reportProgress('1234567890', 4, 5, '5');

    expect(service.currentWord, '5');
    expect(service.currentPassage, '1234567890');
    expect(service.currentPassageHighlightStart, 4);
    expect(service.currentPassageHighlightEnd, 5);
    expect(service.progress, 0.5);
    expect(service.progressPercent, 50);

    service.dispose();
  });

  test('shows the sentence surrounding the currently spoken word', () async {
    final fakeTts = FakeFlutterTts();
    final service = ReaderTtsService(flutterTts: fakeTts);
    const text =
        'First sentence. This is the current sentence for reading. Last sentence.';
    final start = text.indexOf('current');

    await service.speakPage(text: text, pageNumber: 7);
    fakeTts.reportProgress(text, start, start + 7, 'current');

    expect(service.currentPassage, 'This is the current sentence for reading.');
    expect(
      service.currentPassage.substring(
        service.currentPassageHighlightStart,
        service.currentPassageHighlightEnd,
      ),
      'current',
    );

    service.dispose();
  });

  test('highlights the correct occurrence of a repeated word', () async {
    final fakeTts = FakeFlutterTts();
    final service = ReaderTtsService(flutterTts: fakeTts);
    const text = 'Read this word and then read this word carefully.';
    final start = text.lastIndexOf('word');

    await service.speakPage(text: text, pageNumber: 7);
    fakeTts.reportProgress(text, start, start + 4, 'word');

    expect(
      service.currentPassageHighlightStart,
      service.currentPassage.lastIndexOf('word'),
    );
    expect(
      service.currentPassage.substring(
        service.currentPassageHighlightStart,
        service.currentPassageHighlightEnd,
      ),
      'word',
    );

    service.dispose();
  });

  test('trims a very long sentence to a readable phrase', () async {
    final fakeTts = FakeFlutterTts();
    final service = ReaderTtsService(flutterTts: fakeTts);
    final text =
        '${List.filled(35, 'context').join(' ')} important '
        '${List.filled(35, 'detail').join(' ')}.';
    final start = text.indexOf('important');

    await service.speakPage(text: text, pageNumber: 7);
    fakeTts.reportProgress(text, start, start + 9, 'important');

    expect(service.currentPassage, contains('important'));
    expect(
      service.currentPassage.length,
      lessThanOrEqualTo(ReaderTtsService.maximumPassageLength + 10),
    );

    service.dispose();
  });

  test('resumes paused narration without resetting progress', () async {
    final fakeTts = FakeFlutterTts();
    final service = ReaderTtsService(flutterTts: fakeTts);

    await service.speakPage(text: '1234567890', pageNumber: 7);
    fakeTts.reportProgress('1234567890', 4, 5, '5');
    await service.pause();
    final resumed = await service.resume();

    expect(resumed, isTrue);
    expect(fakeTts.speakCount, 2);
    expect(service.progressPercent, 50);

    service.dispose();
  });

  test('starts saved narration from its stored character offset', () async {
    final fakeTts = FakeFlutterTts();
    final service = ReaderTtsService(flutterTts: fakeTts);

    await service.speakPage(
      text: '1234567890',
      pageNumber: 7,
      startCharacter: 5,
    );
    fakeTts.reportProgress('67890', 0, 1, '6');

    expect(fakeTts.spokenText, '67890');
    expect(service.currentCharacterOffset, 6);
    expect(service.progressPercent, 60);

    service.dispose();
  });

  test('ignores interrupted error during intentional saved resume', () async {
    final fakeTts = FakeFlutterTts();
    final service = ReaderTtsService(flutterTts: fakeTts);

    await service.speakPage(
      text: '1234567890',
      pageNumber: 7,
      startCharacter: 5,
    );
    fakeTts.reportError('interrupted');

    expect(service.state, isNot(ReaderNarrationState.error));
    expect(service.errorMessage, isNull);

    service.dispose();
  });

  test('stop resets narration progress', () async {
    final fakeTts = FakeFlutterTts();
    final service = ReaderTtsService(flutterTts: fakeTts);

    await service.speakPage(text: '1234567890', pageNumber: 7);
    fakeTts.reportProgress('1234567890', 4, 5, '5');
    await service.stop();

    expect(service.progressPercent, 0);

    service.dispose();
  });

  test('natural page completion requests continuous narration', () async {
    final fakeTts = FakeFlutterTts();
    int? completedPage;
    final service = ReaderTtsService(
      flutterTts: fakeTts,
      onPageCompleted: (pageNumber) async {
        completedPage = pageNumber;
      },
    );

    await service.speakPage(text: '1234567890', pageNumber: 7);
    fakeTts.completeSpeech();
    await Future<void>.delayed(Duration.zero);

    expect(service.state, ReaderNarrationState.stopped);
    expect(service.progressPercent, 100);
    expect(service.hasResumableProgress, isFalse);
    expect(completedPage, 7);

    service.dispose();
  });

  test(
    'selected passage completion does not continue to the next page',
    () async {
      final fakeTts = FakeFlutterTts();
      int completionCount = 0;
      final service = ReaderTtsService(
        flutterTts: fakeTts,
        onPageCompleted: (_) async {
          completionCount++;
        },
      );

      await service.speakPage(
        text: 'Selected passage only.',
        pageNumber: 7,
        continueAcrossPages: false,
      );
      fakeTts.completeSpeech();
      await Future<void>.delayed(Duration.zero);

      expect(service.progressPercent, 100);
      expect(completionCount, 0);

      service.dispose();
    },
  );

  test(
    'selected passage remains isolated after controls restart narration',
    () async {
      final fakeTts = FakeFlutterTts();
      int completionCount = 0;
      final service = ReaderTtsService(
        flutterTts: fakeTts,
        onPageCompleted: (_) async {
          completionCount++;
        },
      );

      await service.speakPage(
        text: 'Selected passage only.',
        pageNumber: 7,
        continueAcrossPages: false,
      );
      await service.setRate(0.75);
      await service.pause();
      await service.resume();
      fakeTts.completeSpeech();
      await Future<void>.delayed(Duration.zero);

      expect(completionCount, 0);

      service.dispose();
    },
  );

  test('user stop prevents continuous narration request', () async {
    final fakeTts = FakeFlutterTts();
    int completionCount = 0;
    final service = ReaderTtsService(
      flutterTts: fakeTts,
      onPageCompleted: (_) async {
        completionCount++;
      },
    );

    await service.speakPage(text: '1234567890', pageNumber: 7);
    await service.stop();
    fakeTts.completeSpeech();
    await Future<void>.delayed(Duration.zero);

    expect(completionCount, 0);

    service.dispose();
  });

  test('pause cancels a pending automatic page transition', () async {
    final fakeTts = FakeFlutterTts();
    final service = ReaderTtsService(flutterTts: fakeTts);

    await service.speakPage(text: '1234567890', pageNumber: 7);

    expect(service.canContinueAfterPage(7), isTrue);

    await service.pause();

    expect(service.canContinueAfterPage(7), isFalse);

    service.dispose();
  });

  test('restarts active narration with the selected French voice', () async {
    final fakeTts = FakeFlutterTts(
      availableLanguages: const ['en-US', 'fr-CA'],
    );
    final service = ReaderTtsService(flutterTts: fakeTts);

    await service.speakPage(text: 'Protected learning text.', pageNumber: 7);
    await service.setLanguage(ReaderNarrationLanguage.french);

    expect(fakeTts.selectedLanguage, 'fr-CA');
    expect(fakeTts.speakCount, 2);

    service.dispose();
  });

  test('rejects a page without readable text', () async {
    final fakeTts = FakeFlutterTts();
    final service = ReaderTtsService(flutterTts: fakeTts);

    final started = await service.speakPage(text: '   ', pageNumber: 3);

    expect(started, isFalse);
    expect(service.state, ReaderNarrationState.error);
    expect(service.errorMessage, 'No readable text was found on page 3.');
    expect(fakeTts.spokenText, isNull);

    service.dispose();
  });
}

import 'package:ancient_secure_docs/services/reader_tts_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

class FakeFlutterTts extends FlutterTts {
  FakeFlutterTts({
    this.availableLanguages = const ['en-US', 'fr-FR'],
    List<String>? availableVoiceLanguages,
  }) : availableVoiceLanguages =
           availableVoiceLanguages ?? List.of(availableLanguages);

  final List<String> availableLanguages;
  final List<String> availableVoiceLanguages;
  String? selectedLanguage;
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

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async => 1;

  @override
  Future<dynamic> setVolume(double volume) async => 1;

  @override
  Future<dynamic> setPitch(double pitch) async => 1;

  @override
  Future<dynamic> get getLanguages async => availableLanguages;

  @override
  Future<dynamic> get getVoices async => availableVoiceLanguages
      .map((locale) => {'name': 'Voice $locale', 'locale': locale})
      .toList();

  @override
  Future<dynamic> setLanguage(String language) async {
    selectedLanguage = language;
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

  void reportProgress(String text, int start, int end, String word) {
    progressCallback?.call(text, start, end, word);
  }
}

void main() {
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
      'English available | French not detected',
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

  test('restarts active narration after a speed change', () async {
    final fakeTts = FakeFlutterTts();
    final service = ReaderTtsService(flutterTts: fakeTts);

    await service.speakPage(text: 'Protected learning text.', pageNumber: 7);
    await service.setRate(0.75);

    expect(fakeTts.selectedRate, 0.75);
    expect(fakeTts.speakCount, 2);
    expect(fakeTts.spokenText, 'Protected learning text.');

    service.dispose();
  });

  test('tracks narration progress from spoken character positions', () async {
    final fakeTts = FakeFlutterTts();
    final service = ReaderTtsService(flutterTts: fakeTts);

    await service.speakPage(text: '1234567890', pageNumber: 7);
    fakeTts.reportProgress('1234567890', 4, 5, '5');

    expect(service.currentWord, '5');
    expect(service.progress, 0.5);
    expect(service.progressPercent, 50);

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

  test('stop resets narration progress', () async {
    final fakeTts = FakeFlutterTts();
    final service = ReaderTtsService(flutterTts: fakeTts);

    await service.speakPage(text: '1234567890', pageNumber: 7);
    fakeTts.reportProgress('1234567890', 4, 5, '5');
    await service.stop();

    expect(service.progressPercent, 0);

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

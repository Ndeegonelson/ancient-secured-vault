import 'package:ancient_secure_docs/services/reader_tts_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

class FakeFlutterTts extends FlutterTts {
  String? selectedLanguage;
  double? selectedRate;
  String? spokenText;
  int stopCount = 0;

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async => 1;

  @override
  Future<dynamic> setVolume(double volume) async => 1;

  @override
  Future<dynamic> setPitch(double pitch) async => 1;

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
    return 1;
  }

  @override
  Future<dynamic> stop() async {
    stopCount++;
    return 1;
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

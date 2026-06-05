import 'package:ancient_secure_docs/services/reader_narration_access_policy.dart';
import 'package:ancient_secure_docs/services/reader_narration_playback_coordinator.dart';
import 'package:ancient_secure_docs/services/reader_narration_playback_plan.dart';
import 'package:ancient_secure_docs/services/reader_narration_playback_router.dart';
import 'package:ancient_secure_docs/services/reader_narration_voice.dart';
import 'package:ancient_secure_docs/services/reader_tts_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

class CoordinatorTestFlutterTts extends FlutterTts {
  String? spokenText;
  Map<String, String>? selectedVoice;
  VoidCallback? startCallback;

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async => 1;

  @override
  Future<dynamic> setVolume(double volume) async => 1;

  @override
  Future<dynamic> setPitch(double pitch) async => 1;

  @override
  Future<dynamic> get getLanguages async => ['en-US'];

  @override
  Future<dynamic> get getVoices async => [
    {'name': 'Microsoft David', 'locale': 'en-US'},
    {'name': 'Microsoft Zira', 'locale': 'en-US'},
  ];

  @override
  Future<dynamic> setLanguage(String language) async => 1;

  @override
  Future<dynamic> setVoice(Map<String, String> voice) async {
    selectedVoice = voice;
    return 1;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    spokenText = text;
    startCallback?.call();
    return 1;
  }

  @override
  Future<dynamic> stop() async => 1;

  @override
  Future<dynamic> pause() async => 1;

  @override
  void setStartHandler(VoidCallback callback) {
    startCallback = callback;
  }

  @override
  void setPauseHandler(VoidCallback callback) {}

  @override
  void setContinueHandler(VoidCallback callback) {}

  @override
  void setCompletionHandler(VoidCallback callback) {}

  @override
  void setCancelHandler(VoidCallback callback) {}

  @override
  void setProgressHandler(ProgressHandler callback) {}

  @override
  void setErrorHandler(ErrorHandler callback) {}
}

class CoordinatorTestBrowserDelegate
    implements
        ReaderBrowserNarrationDelegate,
        ReaderNarrationPlaybackStatusSource {
  ReaderNarrationVoice? selectedVoice;
  int starts = 0;
  int pauses = 0;
  int resumes = 0;
  int stops = 0;
  int startCharacter = 0;
  bool continueAcrossPages = true;
  bool resumeResult = true;
  String? startedText;

  @override
  int get playbackProgressPercent => 42;

  @override
  int get playbackCharacterStart => startCharacter;

  @override
  int get playbackCharacterEnd => startCharacter + 10;

  @override
  String? get playbackErrorMessage => null;

  @override
  Future<void> setVoice(ReaderNarrationVoice voice) async {
    selectedVoice = voice;
  }

  @override
  Future<bool> startBrowserNarration({
    required String text,
    required int pageNumber,
    required int startCharacter,
    required bool continueAcrossPages,
  }) async {
    starts++;
    startedText = text;
    this.startCharacter = startCharacter;
    this.continueAcrossPages = continueAcrossPages;
    return true;
  }

  @override
  Future<void> pauseBrowserNarration() async {
    pauses++;
  }

  @override
  Future<bool> resumeBrowserNarration() async {
    resumes++;
    return resumeResult;
  }

  @override
  Future<void> stopBrowserNarration() async {
    stops++;
  }
}

const coordinatorCloudVoice = ReaderNarrationVoice(
  name: 'African English Guide',
  locale: 'en-GH',
  cloudVoiceId: 'demo-provider:african-english',
  provider: ReaderNarrationVoiceProvider.cloudAi,
  providerKey: 'firebase-functions',
);

ReaderNarrationAccessPolicy policy({bool premium = true}) {
  return ReaderNarrationAccessPolicy.fromUserAccess(
    isAdmin: false,
    hasActiveSubscription: premium,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds playback snapshots from the current access policy', () async {
    var premium = false;
    final fakeTts = CoordinatorTestFlutterTts();
    final service = ReaderTtsService(flutterTts: fakeTts);
    await service.initialize();

    final coordinator = ReaderNarrationPlaybackCoordinator(
      ttsService: service,
      accessPolicyProvider: () => policy(premium: premium),
    );

    final freeSnapshot = coordinator.snapshot();
    premium = true;
    final premiumSnapshot = coordinator.snapshot();

    expect(freeSnapshot.catalog.canChooseVoice, isFalse);
    expect(freeSnapshot.selectableVoices, hasLength(1));
    expect(premiumSnapshot.catalog.canChooseVoice, isTrue);
    expect(premiumSnapshot.selectableVoices, hasLength(2));

    service.dispose();
  });

  test('selects a browser narrator through the active router', () async {
    final fakeTts = CoordinatorTestFlutterTts();
    final service = ReaderTtsService(flutterTts: fakeTts);
    await service.initialize();
    final browser = CoordinatorTestBrowserDelegate();
    final router = ReaderNarrationPlaybackRouter(browserDelegate: browser);
    final coordinator = ReaderNarrationPlaybackCoordinator(
      ttsService: service,
      accessPolicyProvider: () => policy(),
      router: router,
    );

    final selectedVoice = service.availableBrowserVoices.last;
    final selected = await coordinator.selectVoice(selectedVoice);

    expect(selected, isTrue);
    expect(browser.selectedVoice, selectedVoice);

    service.dispose();
  });

  test('rejects unavailable cloud narrator selection', () async {
    final fakeTts = CoordinatorTestFlutterTts();
    final service = ReaderTtsService(flutterTts: fakeTts);
    await service.initialize();
    final browser = CoordinatorTestBrowserDelegate();
    final router = ReaderNarrationPlaybackRouter(browserDelegate: browser);
    final coordinator = ReaderNarrationPlaybackCoordinator(
      ttsService: service,
      accessPolicyProvider: () => policy(),
      router: router,
    );

    final selected = await coordinator.selectVoice(coordinatorCloudVoice);

    expect(selected, isFalse);
    expect(browser.selectedVoice, isNull);

    service.dispose();
  });

  test(
    'starts narration through the router using the latest snapshot',
    () async {
      final fakeTts = CoordinatorTestFlutterTts();
      final service = ReaderTtsService(flutterTts: fakeTts);
      await service.initialize();
      final browser = CoordinatorTestBrowserDelegate();
      final router = ReaderNarrationPlaybackRouter(browserDelegate: browser);
      final coordinator = ReaderNarrationPlaybackCoordinator(
        ttsService: service,
        accessPolicyProvider: () => policy(),
        router: router,
      );

      final selectedVoice = service.availableBrowserVoices.last;
      final started = await coordinator.start(
        text: 'Protected narration text.',
        pageNumber: 7,
        rate: 0.8,
        startCharacter: 5,
        continueAcrossPages: false,
        selectedVoice: selectedVoice,
      );

      expect(started, isTrue);
      expect(coordinator.state, ReaderNarrationRouterState.playing);
      expect(coordinator.status.progressPercent, 42);
      expect(coordinator.status.currentCharacterStart, 5);
      expect(coordinator.status.currentCharacterEnd, 15);
      expect(browser.selectedVoice, selectedVoice);
      expect(browser.startedText, 'Protected narration text.');
      expect(browser.continueAcrossPages, isFalse);

      service.dispose();
    },
  );

  test(
    'delegates pause resume stop and stopAll to the active router',
    () async {
      final fakeTts = CoordinatorTestFlutterTts();
      final service = ReaderTtsService(flutterTts: fakeTts);
      await service.initialize();
      final browser = CoordinatorTestBrowserDelegate();
      final router = ReaderNarrationPlaybackRouter(browserDelegate: browser);
      final coordinator = ReaderNarrationPlaybackCoordinator(
        ttsService: service,
        accessPolicyProvider: () => policy(),
        router: router,
      );

      await coordinator.start(
        text: 'Protected narration text.',
        pageNumber: 2,
        rate: 1,
      );
      await coordinator.pause();
      final resumed = await coordinator.resume();
      await coordinator.stop();
      await coordinator.stopAll();

      expect(resumed, isTrue);
      expect(browser.pauses, 1);
      expect(browser.resumes, 1);
      expect(browser.stops, 2);
      expect(coordinator.state, ReaderNarrationRouterState.stopped);

      service.dispose();
    },
  );

  test('falls back when a selected cloud voice is unavailable', () async {
    final fakeTts = CoordinatorTestFlutterTts();
    final service = ReaderTtsService(flutterTts: fakeTts);
    await service.initialize();
    final coordinator = ReaderNarrationPlaybackCoordinator(
      ttsService: service,
      accessPolicyProvider: () => policy(),
    );

    final snapshot = coordinator.snapshot(selectedVoice: coordinatorCloudVoice);

    expect(snapshot.plan.engine, ReaderNarrationPlaybackEngine.browser);
    expect(
      snapshot.statusMessage,
      'Cloud narrators have not been checked yet.',
    );

    service.dispose();
  });
}

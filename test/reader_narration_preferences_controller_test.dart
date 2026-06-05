import 'package:ancient_secure_docs/services/reader_narration_access_policy.dart';
import 'package:ancient_secure_docs/services/reader_narration_playback_coordinator.dart';
import 'package:ancient_secure_docs/services/reader_narration_playback_router.dart';
import 'package:ancient_secure_docs/services/reader_narration_preferences_controller.dart';
import 'package:ancient_secure_docs/services/reader_narration_preferences_repository.dart';
import 'package:ancient_secure_docs/services/reader_narration_voice.dart';
import 'package:ancient_secure_docs/services/reader_tts_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

class PreferencesControllerTestFlutterTts extends FlutterTts {
  PreferencesControllerTestFlutterTts({
    this.availableVoices = const [
      {'name': 'Assigned Voice', 'locale': 'en-US'},
      {'name': 'Premium Voice', 'locale': 'en-GB'},
    ],
  });

  final List<Map<String, String>> availableVoices;
  Map<String, String>? selectedVoice;
  double? selectedRate;
  VoidCallback? startCallback;

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async => 1;

  @override
  Future<dynamic> setVolume(double volume) async => 1;

  @override
  Future<dynamic> setPitch(double pitch) async => 1;

  @override
  Future<dynamic> get getLanguages async => ['en-US', 'en-GB', 'fr-FR'];

  @override
  Future<dynamic> get getVoices async => availableVoices;

  @override
  Future<dynamic> setLanguage(String language) async => 1;

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

class FakeNarrationPreferencesStore implements ReaderNarrationPreferencesStore {
  ReaderNarrationPreferences? loadedPreferences;
  ReaderNarrationPreferences? savedPreferences;
  int loadCalls = 0;
  int saveCalls = 0;
  bool throwOnLoad = false;
  bool throwOnSave = false;

  @override
  Future<ReaderNarrationPreferences?> load({required String userEmail}) async {
    if (throwOnLoad) throw StateError('offline');
    loadCalls++;
    return loadedPreferences;
  }

  @override
  Future<void> save({
    required String userEmail,
    required ReaderNarrationPreferences preferences,
  }) async {
    if (throwOnSave) throw StateError('offline');
    saveCalls++;
    savedPreferences = preferences;
  }
}

class PreferencesControllerBrowserDelegate
    implements ReaderBrowserNarrationDelegate {
  ReaderNarrationVoice? selectedVoice;
  int stopCalls = 0;

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
    return true;
  }

  @override
  Future<void> pauseBrowserNarration() async {}

  @override
  Future<bool> resumeBrowserNarration() async => true;

  @override
  Future<void> stopBrowserNarration() async {
    stopCalls++;
  }
}

const preferencesContext = ReaderNarrationPreferencesContext(
  userEmail: 'reader@example.com',
);

ReaderNarrationAccessPolicy premiumPolicy() {
  return ReaderNarrationAccessPolicy.fromUserAccess(
    isAdmin: false,
    hasActiveSubscription: true,
  );
}

ReaderNarrationPreferencesController controllerFor({
  required FakeNarrationPreferencesStore store,
  required ReaderTtsService service,
  required ReaderNarrationPlaybackCoordinator coordinator,
}) {
  return ReaderNarrationPreferencesController(
    store: store,
    ttsService: service,
    playbackCoordinator: coordinator,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads saved narration preferences into the tts service', () async {
    final store = FakeNarrationPreferencesStore()
      ..loadedPreferences = const ReaderNarrationPreferences(
        languageMode: 'auto',
        rate: 0.75,
        voiceId: 'browser|en-GB|Premium Voice',
      );
    final service = ReaderTtsService(
      flutterTts: PreferencesControllerTestFlutterTts(),
    );
    final coordinator = ReaderNarrationPlaybackCoordinator(
      ttsService: service,
      accessPolicyProvider: premiumPolicy,
    );
    final controller = controllerFor(
      store: store,
      service: service,
      coordinator: coordinator,
    );

    final preferences = await controller.load(context: preferencesContext);

    expect(preferences, isNotNull);
    expect(service.language, ReaderNarrationLanguage.auto);
    expect(service.rate, 0.75);
    expect(service.preferredVoiceId, 'browser|en-GB|Premium Voice');
    expect(store.loadCalls, 1);

    service.dispose();
  });

  test('skips preference loading for anonymous readers', () async {
    final store = FakeNarrationPreferencesStore();
    final service = ReaderTtsService(
      flutterTts: PreferencesControllerTestFlutterTts(),
    );
    final coordinator = ReaderNarrationPlaybackCoordinator(
      ttsService: service,
      accessPolicyProvider: premiumPolicy,
    );
    final controller = controllerFor(
      store: store,
      service: service,
      coordinator: coordinator,
    );

    final preferences = await controller.load(
      context: const ReaderNarrationPreferencesContext(userEmail: null),
    );

    expect(preferences, isNull);
    expect(store.loadCalls, 0);

    service.dispose();
  });

  test('saves the current language rate and narrator voice', () async {
    final store = FakeNarrationPreferencesStore();
    final service = ReaderTtsService(
      flutterTts: PreferencesControllerTestFlutterTts(),
    );
    final coordinator = ReaderNarrationPlaybackCoordinator(
      ttsService: service,
      accessPolicyProvider: premiumPolicy,
    );
    final controller = controllerFor(
      store: store,
      service: service,
      coordinator: coordinator,
    );

    service.restorePreferences(
      language: ReaderNarrationLanguage.french,
      rate: 0.65,
      voiceId: 'browser|fr-FR|French Voice',
    );
    final result = await controller.saveCurrent(
      context: preferencesContext,
      selectedVoiceId: 'browser|fr-FR|French Voice',
    );

    expect(result, ReaderNarrationPreferencesWriteResult.saved);
    expect(store.saveCalls, 1);
    expect(store.savedPreferences?.languageMode, 'fr-FR');
    expect(store.savedPreferences?.rate, 0.65);
    expect(store.savedPreferences?.voiceId, 'browser|fr-FR|French Voice');

    service.dispose();
  });

  test('reports failed preference saves without throwing', () async {
    final store = FakeNarrationPreferencesStore()..throwOnSave = true;
    final service = ReaderTtsService(
      flutterTts: PreferencesControllerTestFlutterTts(),
    );
    final coordinator = ReaderNarrationPlaybackCoordinator(
      ttsService: service,
      accessPolicyProvider: premiumPolicy,
    );
    final controller = controllerFor(
      store: store,
      service: service,
      coordinator: coordinator,
    );

    final result = await controller.saveCurrent(context: preferencesContext);

    expect(result, ReaderNarrationPreferencesWriteResult.failed);

    service.dispose();
  });

  test(
    'routes narrator changes through playback coordinator before saving',
    () async {
      final store = FakeNarrationPreferencesStore();
      final fakeTts = PreferencesControllerTestFlutterTts();
      final service = ReaderTtsService(flutterTts: fakeTts);
      await service.initialize();
      final browser = PreferencesControllerBrowserDelegate();
      final router = ReaderNarrationPlaybackRouter(browserDelegate: browser);
      final coordinator = ReaderNarrationPlaybackCoordinator(
        ttsService: service,
        accessPolicyProvider: premiumPolicy,
        router: router,
      );
      final controller = controllerFor(
        store: store,
        service: service,
        coordinator: coordinator,
      );

      final voice = service.availableBrowserVoices.last;
      final changed = await controller.changeVoice(
        context: preferencesContext,
        voice: voice,
      );

      expect(changed, isTrue);
      expect(browser.selectedVoice, voice);
      expect(store.savedPreferences?.voiceId, voice.id);

      service.dispose();
    },
  );
}

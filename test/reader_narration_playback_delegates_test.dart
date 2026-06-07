import 'package:ancient_secure_docs/services/reader_cloud_narration_audio_player.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_playback_controller.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_preparation_queue.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_provider.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_registry.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_session_coordinator.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_text_planner.dart';
import 'package:ancient_secure_docs/services/reader_narration_access_policy.dart';
import 'package:ancient_secure_docs/services/reader_narration_playback_delegates.dart';
import 'package:ancient_secure_docs/services/reader_narration_voice.dart';
import 'package:ancient_secure_docs/services/reader_tts_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

class DelegateTestFlutterTts extends FlutterTts {
  String? spokenText;
  int stopCount = 0;
  int pauseCount = 0;
  Map<String, String>? selectedVoice;
  VoidCallback? startCallback;
  VoidCallback? pauseCallback;
  ProgressHandler? progressCallback;

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
  Future<dynamic> pause() async {
    pauseCount++;
    pauseCallback?.call();
    return 1;
  }

  @override
  Future<dynamic> stop() async {
    stopCount++;
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
  void setContinueHandler(VoidCallback callback) {}

  @override
  void setCompletionHandler(VoidCallback callback) {}

  @override
  void setCancelHandler(VoidCallback callback) {}

  @override
  void setProgressHandler(ProgressHandler callback) {
    progressCallback = callback;
  }

  @override
  void setErrorHandler(ErrorHandler callback) {}

  void reportProgress(String text, int start, int end, String word) {
    progressCallback?.call(text, start, end, word);
  }
}

class DelegateTestCloudProvider implements ReaderCloudNarrationProvider {
  DelegateTestCloudProvider({required this.voices});

  final List<ReaderNarrationVoice> voices;
  final List<ReaderCloudNarrationSynthesisRequest> requests = [];

  @override
  String get key => 'test-cloud';

  @override
  String get displayName => 'Test Cloud';

  @override
  ReaderCloudNarrationProviderCapabilities get capabilities =>
      const ReaderCloudNarrationProviderCapabilities(
        supportsStreamingAudio: false,
        supportsWordTimings: false,
        supportsVoiceStyles: true,
        supportsCustomVoices: true,
      );

  @override
  Future<ReaderCloudNarrationProviderStatus> checkStatus() async {
    return const ReaderCloudNarrationProviderStatus(
      state: ReaderCloudNarrationProviderState.ready,
      message: 'Ready',
    );
  }

  @override
  Future<List<ReaderNarrationVoice>> loadVoices() async => voices;

  @override
  Future<ReaderCloudNarrationAudioSegment> synthesize(
    ReaderCloudNarrationSynthesisRequest request,
  ) async {
    requests.add(request);
    return ReaderCloudNarrationAudioSegment(
      audioBytes: Uint8List.fromList([1]),
      contentType: 'audio/wav',
      startCharacter: request.startCharacter,
      endCharacter: request.endCharacter,
    );
  }
}

class DelegateTestAudioPlayer implements ReaderCloudNarrationAudioPlayer {
  int playCount = 0;
  int pauseCount = 0;
  int resumeCount = 0;
  int stopCount = 0;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> load(ReaderCloudNarrationAudioSegment segment) async {}

  @override
  Future<void> pause() async {
    pauseCount++;
  }

  @override
  Future<void> play() async {
    playCount++;
  }

  @override
  Future<void> resume() async {
    resumeCount++;
  }

  @override
  void setCompletionHandler(VoidCallback handler) {}

  @override
  void setErrorHandler(ValueChanged<String> handler) {}

  @override
  void setPositionHandler(ValueChanged<Duration> handler) {}

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

const browserVoice = ReaderNarrationVoice(
  name: 'Microsoft David',
  locale: 'en-US',
);

const cloudVoice = ReaderNarrationVoice(
  name: 'Cloud Guide',
  locale: 'en-GH',
  cloudVoiceId: 'test-cloud:guide',
  provider: ReaderNarrationVoiceProvider.cloudAi,
  providerKey: 'test-cloud',
);

ReaderNarrationAccessPolicy premiumPolicy() {
  return ReaderNarrationAccessPolicy.fromUserAccess(
    isAdmin: false,
    hasActiveSubscription: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('browser delegate forwards commands to ReaderTtsService', () async {
    final fakeTts = DelegateTestFlutterTts();
    final service = ReaderTtsService(flutterTts: fakeTts);
    final delegate = ReaderTtsBrowserNarrationDelegate(service);
    await service.initialize();

    await delegate.setVoice(browserVoice);
    final started = await delegate.startBrowserNarration(
      text: 'Protected learning text.',
      pageNumber: 2,
      startCharacter: 10,
      continueAcrossPages: false,
    );
    fakeTts.reportProgress('learning text.', 0, 8, 'learning');

    expect(started, isTrue);
    expect(fakeTts.selectedVoice, browserVoice.browserVoice);
    expect(fakeTts.spokenText, 'learning text.');
    expect(delegate.playbackProgressPercent, 75);
    expect(delegate.playbackCharacterStart, 18);
    expect(delegate.playbackCharacterEnd, 18);

    await delegate.pauseBrowserNarration();
    await delegate.stopBrowserNarration();

    expect(fakeTts.pauseCount, 1);
    expect(fakeTts.stopCount, greaterThanOrEqualTo(1));

    service.dispose();
  });

  test(
    'cloud delegate forwards commands to cloud session coordinator',
    () async {
      final provider = DelegateTestCloudProvider(voices: const [cloudVoice]);
      final player = DelegateTestAudioPlayer();
      final registry = ReaderCloudNarrationRegistry(providers: [provider]);
      final queue = ReaderCloudNarrationPreparationQueue(
        registry: registry,
        planner: const ReaderCloudNarrationTextPlanner(
          maximumSegmentCharacters: 80,
        ),
      );
      final playbackController = ReaderCloudNarrationPlaybackController(
        queue: queue,
        audioPlayer: player,
      );
      final session = ReaderCloudNarrationSessionCoordinator(
        registry: registry,
        playbackController: playbackController,
        accessPolicy: premiumPolicy(),
      );
      final delegate = ReaderCloudSessionNarrationDelegate(session);

      await session.refreshCatalog();
      final selected = await delegate.selectCloudVoice(cloudVoice);
      final started = await delegate.startCloudNarration(
        text: 'Protected cloud learning text.',
        rate: 0.8,
        startCharacter: 4,
      );
      await delegate.pauseCloudNarration();
      await delegate.resumeCloudNarration();
      await delegate.stopCloudNarration();

      expect(selected, isTrue);
      expect(started, isTrue);
      expect(provider.requests.single.startCharacter, 4);
      expect(provider.requests.single.rate, 0.8);
      expect(player.playCount, 1);
      expect(player.pauseCount, 1);
      expect(player.resumeCount, 1);
      expect(player.stopCount, greaterThanOrEqualTo(1));

      session.dispose();
    },
  );
}

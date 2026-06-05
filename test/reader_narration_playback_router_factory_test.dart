import 'package:ancient_secure_docs/services/reader_cloud_narration_audio_player.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_playback_controller.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_preparation_queue.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_provider.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_registry.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_session_coordinator.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_text_planner.dart';
import 'package:ancient_secure_docs/services/reader_narration_access_policy.dart';
import 'package:ancient_secure_docs/services/reader_narration_playback_plan.dart';
import 'package:ancient_secure_docs/services/reader_narration_playback_router.dart';
import 'package:ancient_secure_docs/services/reader_narration_playback_router_factory.dart';
import 'package:ancient_secure_docs/services/reader_narration_playback_snapshot.dart';
import 'package:ancient_secure_docs/services/reader_narration_voice.dart';
import 'package:ancient_secure_docs/services/reader_narration_voice_catalog.dart';
import 'package:ancient_secure_docs/services/reader_tts_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

class FactoryTestFlutterTts extends FlutterTts {
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

class FactoryTestCloudProvider implements ReaderCloudNarrationProvider {
  FactoryTestCloudProvider({required this.voices});

  final List<ReaderNarrationVoice> voices;
  int synthesisCalls = 0;

  @override
  String get key => 'factory-cloud';

  @override
  String get displayName => 'Factory Cloud';

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
    synthesisCalls++;
    return ReaderCloudNarrationAudioSegment(
      audioBytes: Uint8List.fromList([1]),
      contentType: 'audio/wav',
      startCharacter: request.startCharacter,
      endCharacter: request.endCharacter,
    );
  }
}

class FactoryTestAudioPlayer implements ReaderCloudNarrationAudioPlayer {
  int playCount = 0;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> load(ReaderCloudNarrationAudioSegment segment) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {
    playCount++;
  }

  @override
  Future<void> resume() async {}

  @override
  void setCompletionHandler(VoidCallback handler) {}

  @override
  void setErrorHandler(ValueChanged<String> handler) {}

  @override
  void setPositionHandler(ValueChanged<Duration> handler) {}

  @override
  Future<void> stop() async {}
}

const browserVoice = ReaderNarrationVoice(
  name: 'Microsoft David',
  locale: 'en-US',
);

const cloudVoice = ReaderNarrationVoice(
  name: 'Factory Cloud Guide',
  locale: 'en-GH',
  cloudVoiceId: 'factory-cloud:guide',
  provider: ReaderNarrationVoiceProvider.cloudAi,
  providerKey: 'factory-cloud',
);

ReaderNarrationAccessPolicy premiumPolicy() {
  return ReaderNarrationAccessPolicy.fromUserAccess(
    isAdmin: false,
    hasActiveSubscription: true,
  );
}

ReaderNarrationPlaybackSnapshot snapshotFor(ReaderNarrationVoice voice) {
  final catalog = ReaderNarrationVoiceCatalog(
    accessPolicy: premiumPolicy(),
    locale: 'en-US',
    assignedVoice: browserVoice,
    defaultVoice: voice,
    browserVoices: const [browserVoice],
    cloudVoices: voice.provider == ReaderNarrationVoiceProvider.cloudAi
        ? const [cloudVoice]
        : const [],
    selectableVoices: voice.provider == ReaderNarrationVoiceProvider.cloudAi
        ? const [browserVoice, cloudVoice]
        : const [browserVoice],
    providerStatuses: const {},
  );
  return ReaderNarrationPlaybackSnapshot(
    catalog: catalog,
    plan: ReaderNarrationPlaybackPlan.ready(
      engine: voice.provider == ReaderNarrationVoiceProvider.cloudAi
          ? ReaderNarrationPlaybackEngine.cloud
          : ReaderNarrationPlaybackEngine.browser,
      voice: voice,
      message: 'Ready',
    ),
  );
}

ReaderNarrationPlaybackStartRequest requestFor(ReaderNarrationVoice voice) {
  return ReaderNarrationPlaybackStartRequest(
    snapshot: snapshotFor(voice),
    text: 'Protected narration text.',
    pageNumber: 1,
    rate: 0.8,
  );
}

void main() {
  test(
    'creates a browser-only router when no cloud session is supplied',
    () async {
      final fakeTts = FactoryTestFlutterTts();
      final service = ReaderTtsService(flutterTts: fakeTts);
      await service.initialize();

      final router = const ReaderNarrationPlaybackRouterFactory().create(
        ttsService: service,
      );

      final browserStarted = await router.start(requestFor(browserVoice));
      final cloudStarted = await router.start(requestFor(cloudVoice));

      expect(browserStarted, isTrue);
      expect(fakeTts.selectedVoice, browserVoice.browserVoice);
      expect(fakeTts.spokenText, 'Protected narration text.');
      expect(cloudStarted, isFalse);
      expect(
        router.errorMessage,
        'Secure cloud narration is not connected yet.',
      );

      service.dispose();
    },
  );

  test(
    'creates a cloud-capable router when cloud session is supplied',
    () async {
      final fakeTts = FactoryTestFlutterTts();
      final service = ReaderTtsService(flutterTts: fakeTts);
      await service.initialize();

      final provider = FactoryTestCloudProvider(voices: const [cloudVoice]);
      final player = FactoryTestAudioPlayer();
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
      await session.refreshCatalog();

      final router = const ReaderNarrationPlaybackRouterFactory().create(
        ttsService: service,
        cloudSession: session,
      );

      final started = await router.start(requestFor(cloudVoice));

      expect(started, isTrue);
      expect(provider.synthesisCalls, 1);
      expect(player.playCount, 1);
      expect(router.isUsingCloud, isTrue);

      session.dispose();
      service.dispose();
    },
  );
}

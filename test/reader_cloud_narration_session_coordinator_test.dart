import 'dart:async';

import 'package:ancient_secure_docs/services/reader_cloud_narration_audio_player.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_playback_controller.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_preparation_queue.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_provider.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_registry.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_session_coordinator.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_text_planner.dart';
import 'package:ancient_secure_docs/services/reader_narration_access_policy.dart';
import 'package:ancient_secure_docs/services/reader_narration_voice.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class SessionTestCloudProvider implements ReaderCloudNarrationProvider {
  SessionTestCloudProvider({this.voices = const [], this.statusDelay});

  final List<ReaderNarrationVoice> voices;
  final Completer<void>? statusDelay;
  int statusCheckCount = 0;

  @override
  String get key => 'session-provider';

  @override
  String get displayName => 'Session Provider';

  @override
  ReaderCloudNarrationProviderCapabilities get capabilities =>
      const ReaderCloudNarrationProviderCapabilities(
        supportsStreamingAudio: false,
        supportsWordTimings: true,
        supportsVoiceStyles: true,
        supportsCustomVoices: true,
      );

  @override
  Future<ReaderCloudNarrationProviderStatus> checkStatus() async {
    statusCheckCount++;
    await statusDelay?.future;
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
    return ReaderCloudNarrationAudioSegment(
      audioBytes: Uint8List.fromList([1]),
      contentType: 'audio/mpeg',
      startCharacter: request.startCharacter,
      endCharacter: request.endCharacter,
      duration: const Duration(seconds: 1),
    );
  }
}

class SessionTestAudioPlayer implements ReaderCloudNarrationAudioPlayer {
  ValueChanged<Duration>? positionHandler;
  VoidCallback? completionHandler;
  ValueChanged<String>? errorHandler;
  int loadCount = 0;
  int playCount = 0;
  int stopCount = 0;
  Completer<void>? stopDelay;

  @override
  void setPositionHandler(ValueChanged<Duration> handler) {
    positionHandler = handler;
  }

  @override
  void setCompletionHandler(VoidCallback handler) {
    completionHandler = handler;
  }

  @override
  void setErrorHandler(ValueChanged<String> handler) {
    errorHandler = handler;
  }

  @override
  Future<void> load(ReaderCloudNarrationAudioSegment segment) async {
    loadCount++;
  }

  @override
  Future<void> play() async {
    playCount++;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {
    stopCount++;
    await stopDelay?.future;
  }

  @override
  Future<void> dispose() async {}

  void reportError(String message) => errorHandler?.call(message);
}

void main() {
  const englishVoice = ReaderNarrationVoice(
    name: 'Ama',
    locale: 'en-GH',
    accent: 'Ghanaian',
  );
  const frenchVoice = ReaderNarrationVoice(
    name: 'Kofi',
    locale: 'fr-GH',
    accent: 'Ghanaian',
  );

  ReaderNarrationAccessPolicy policy({
    bool isAdmin = false,
    bool hasActiveSubscription = true,
  }) {
    return ReaderNarrationAccessPolicy.fromUserAccess(
      isAdmin: isAdmin,
      hasActiveSubscription: hasActiveSubscription,
    );
  }

  ({
    ReaderCloudNarrationSessionCoordinator coordinator,
    SessionTestAudioPlayer player,
  })
  createCoordinator(
    SessionTestCloudProvider provider, {
    ReaderNarrationAccessPolicy? accessPolicy,
  }) {
    final player = SessionTestAudioPlayer();
    final registry = ReaderCloudNarrationRegistry(providers: [provider]);
    final queue = ReaderCloudNarrationPreparationQueue(
      registry: registry,
      planner: const ReaderCloudNarrationTextPlanner(
        maximumSegmentCharacters: 30,
      ),
    );
    final playbackController = ReaderCloudNarrationPlaybackController(
      queue: queue,
      audioPlayer: player,
    );
    final coordinator = ReaderCloudNarrationSessionCoordinator(
      registry: registry,
      playbackController: playbackController,
      accessPolicy: accessPolicy ?? policy(),
    );

    return (coordinator: coordinator, player: player);
  }

  test('premium catalog exposes verified cloud voices by language', () async {
    final provider = SessionTestCloudProvider(
      voices: const [englishVoice, frenchVoice],
    );
    final session = createCoordinator(provider);

    final ready = await session.coordinator.refreshCatalog();

    expect(ready, isTrue);
    expect(session.coordinator.state, ReaderCloudNarrationSessionState.ready);
    expect(session.coordinator.availableVoices, hasLength(2));
    expect(session.coordinator.voicesForLocale('fr-FR').single.name, 'Kofi');
    expect(
      session.coordinator.availableVoices.every(
        (voice) => voice.provider == ReaderNarrationVoiceProvider.cloudAi,
      ),
      isTrue,
    );

    session.coordinator.dispose();
  });

  test('free users cannot load or retain the cloud voice catalog', () async {
    final provider = SessionTestCloudProvider(voices: const [englishVoice]);
    final session = createCoordinator(
      provider,
      accessPolicy: policy(hasActiveSubscription: false),
    );

    final ready = await session.coordinator.refreshCatalog();

    expect(ready, isFalse);
    expect(provider.statusCheckCount, 0);
    expect(
      session.coordinator.state,
      ReaderCloudNarrationSessionState.accessDenied,
    );
    expect(session.coordinator.availableVoices, isEmpty);
    expect(
      session.coordinator.errorMessage,
      policy(hasActiveSubscription: false).cloudUpgradeMessage,
    );

    session.coordinator.dispose();
  });

  test('selected catalog voice starts protected cloud playback', () async {
    final provider = SessionTestCloudProvider(voices: const [englishVoice]);
    final session = createCoordinator(provider);

    await session.coordinator.refreshCatalog();
    final selected = await session.coordinator.selectVoice(
      session.coordinator.availableVoices.single,
    );
    final started = await session.coordinator.start(
      text: 'Protected cloud narration text.',
      rate: 0.8,
    );

    expect(selected, isTrue);
    expect(started, isTrue);
    expect(session.coordinator.state, ReaderCloudNarrationSessionState.playing);
    expect(session.player.loadCount, 1);
    expect(session.player.playCount, 1);

    session.coordinator.dispose();
  });

  test('voice outside the verified cloud catalog is rejected', () async {
    final provider = SessionTestCloudProvider(voices: const [englishVoice]);
    final session = createCoordinator(provider);

    await session.coordinator.refreshCatalog();
    final selected = await session.coordinator.selectVoice(
      const ReaderNarrationVoice(name: 'Browser Voice', locale: 'en-US'),
    );

    expect(selected, isFalse);
    expect(session.coordinator.selectedVoice, isNull);
    expect(session.coordinator.state, ReaderCloudNarrationSessionState.error);

    session.coordinator.dispose();
  });

  test('subscription loss immediately clears cloud narration state', () async {
    final provider = SessionTestCloudProvider(voices: const [englishVoice]);
    final session = createCoordinator(provider);

    await session.coordinator.refreshCatalog();
    await session.coordinator.selectVoice(
      session.coordinator.availableVoices.single,
    );
    await session.coordinator.start(
      text: 'Protected cloud narration text.',
      rate: 0.8,
    );
    await session.coordinator.updateAccessPolicy(
      policy(hasActiveSubscription: false),
    );

    expect(
      session.coordinator.state,
      ReaderCloudNarrationSessionState.accessDenied,
    );
    expect(session.coordinator.selectedVoice, isNull);
    expect(session.coordinator.availableVoices, isEmpty);
    expect(
      session.coordinator.playbackController.queue.bufferedSegmentCount,
      0,
    );
    expect(session.player.stopCount, greaterThan(0));

    session.coordinator.dispose();
  });

  test('late voice selection cannot complete after access loss', () async {
    final provider = SessionTestCloudProvider(voices: const [englishVoice]);
    final session = createCoordinator(provider);

    await session.coordinator.refreshCatalog();
    final voice = session.coordinator.availableVoices.single;
    final stopDelay = Completer<void>();
    session.player.stopDelay = stopDelay;

    final selection = session.coordinator.selectVoice(voice);
    await Future<void>.delayed(Duration.zero);
    final accessUpdate = session.coordinator.updateAccessPolicy(
      policy(hasActiveSubscription: false),
    );
    stopDelay.complete();

    expect(await selection, isFalse);
    await accessUpdate;
    expect(
      session.coordinator.state,
      ReaderCloudNarrationSessionState.accessDenied,
    );
    expect(session.coordinator.selectedVoice, isNull);

    session.coordinator.dispose();
  });

  test('access-plan changes preserve active cloud playback state', () async {
    final provider = SessionTestCloudProvider(voices: const [englishVoice]);
    final session = createCoordinator(provider);

    await session.coordinator.refreshCatalog();
    await session.coordinator.selectVoice(
      session.coordinator.availableVoices.single,
    );
    await session.coordinator.start(
      text: 'Protected cloud narration text.',
      rate: 0.8,
    );
    await session.coordinator.updateAccessPolicy(policy(isAdmin: true));

    expect(session.coordinator.state, ReaderCloudNarrationSessionState.playing);
    expect(session.coordinator.selectedVoice, isNotNull);

    session.coordinator.dispose();
  });

  test(
    'late catalog response cannot restore voices after access loss',
    () async {
      final statusDelay = Completer<void>();
      final provider = SessionTestCloudProvider(
        voices: const [englishVoice],
        statusDelay: statusDelay,
      );
      final session = createCoordinator(provider);

      final refresh = session.coordinator.refreshCatalog();
      await Future<void>.delayed(Duration.zero);
      await session.coordinator.updateAccessPolicy(
        policy(hasActiveSubscription: false),
      );
      statusDelay.complete();
      await refresh;

      expect(
        session.coordinator.state,
        ReaderCloudNarrationSessionState.accessDenied,
      );
      expect(session.coordinator.availableVoices, isEmpty);

      session.coordinator.dispose();
    },
  );

  test('playback error is mirrored and protected audio is released', () async {
    final provider = SessionTestCloudProvider(voices: const [englishVoice]);
    final session = createCoordinator(provider);

    await session.coordinator.refreshCatalog();
    await session.coordinator.selectVoice(
      session.coordinator.availableVoices.single,
    );
    await session.coordinator.start(
      text: 'Protected cloud narration text.',
      rate: 0.8,
    );
    session.player.reportError('Protected cloud audio failed.');

    expect(session.coordinator.state, ReaderCloudNarrationSessionState.error);
    expect(session.coordinator.errorMessage, 'Protected cloud audio failed.');
    expect(
      session.coordinator.playbackController.queue.bufferedSegmentCount,
      0,
    );

    session.coordinator.dispose();
  });
}

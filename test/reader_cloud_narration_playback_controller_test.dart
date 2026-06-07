import 'package:ancient_secure_docs/services/reader_cloud_narration_audio_player.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_playback_controller.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_preparation_queue.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_provider.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_registry.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_text_planner.dart';
import 'package:ancient_secure_docs/services/reader_narration_voice.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class PlaybackTestCloudProvider implements ReaderCloudNarrationProvider {
  @override
  String get key => 'playback-provider';

  @override
  String get displayName => 'Playback Provider';

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
    return const ReaderCloudNarrationProviderStatus(
      state: ReaderCloudNarrationProviderState.ready,
      message: 'Ready',
    );
  }

  @override
  Future<List<ReaderNarrationVoice>> loadVoices() async => const [];

  @override
  Future<ReaderCloudNarrationAudioSegment> synthesize(
    ReaderCloudNarrationSynthesisRequest request,
  ) async {
    final midpoint = request.startCharacter + (request.text.length ~/ 2);

    return ReaderCloudNarrationAudioSegment(
      audioBytes: Uint8List.fromList([1, 2, 3]),
      contentType: 'audio/mpeg',
      startCharacter: request.startCharacter,
      endCharacter: request.endCharacter,
      duration: const Duration(seconds: 2),
      timingCues: [
        ReaderCloudNarrationTimingCue(
          startCharacter: request.startCharacter,
          endCharacter: midpoint,
          audioOffset: Duration.zero,
        ),
        ReaderCloudNarrationTimingCue(
          startCharacter: midpoint,
          endCharacter: request.endCharacter,
          audioOffset: const Duration(seconds: 1),
        ),
      ],
    );
  }
}

class FakeCloudNarrationAudioPlayer implements ReaderCloudNarrationAudioPlayer {
  ValueChanged<Duration>? positionHandler;
  VoidCallback? completionHandler;
  ValueChanged<String>? errorHandler;
  final List<ReaderCloudNarrationAudioSegment> loadedSegments = [];
  int playCount = 0;
  int pauseCount = 0;
  int resumeCount = 0;
  int stopCount = 0;
  int disposeCount = 0;
  bool completeDuringStop = false;
  bool completeDuringResume = false;

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
    loadedSegments.add(segment);
  }

  @override
  Future<void> play() async {
    playCount++;
  }

  @override
  Future<void> pause() async {
    pauseCount++;
  }

  @override
  Future<void> resume() async {
    resumeCount++;
    if (completeDuringResume) {
      completionHandler?.call();
    }
  }

  @override
  Future<void> stop() async {
    stopCount++;
    if (completeDuringStop) {
      completionHandler?.call();
    }
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
  }

  void reportPosition(Duration position) => positionHandler?.call(position);

  void completeSegment() => completionHandler?.call();

  void reportError(String message) => errorHandler?.call(message);
}

void main() {
  const voice = ReaderNarrationVoice(
    name: 'Ama',
    locale: 'en-GH',
    provider: ReaderNarrationVoiceProvider.cloudAi,
    providerKey: 'playback-provider',
  );
  const text = 'First segment. Second segment. Third segment.';

  ReaderCloudNarrationPlaybackController createController(
    FakeCloudNarrationAudioPlayer player,
  ) {
    final provider = PlaybackTestCloudProvider();
    final queue = ReaderCloudNarrationPreparationQueue(
      registry: ReaderCloudNarrationRegistry(providers: [provider]),
      planner: const ReaderCloudNarrationTextPlanner(
        maximumSegmentCharacters: 16,
      ),
    );

    return ReaderCloudNarrationPlaybackController(
      queue: queue,
      audioPlayer: player,
    );
  }

  test('starts with the first prepared cloud audio segment', () async {
    final player = FakeCloudNarrationAudioPlayer();
    final controller = createController(player);

    final started = await controller.start(text: text, voice: voice, rate: 0.8);

    expect(started, isTrue);
    expect(controller.state, ReaderCloudNarrationPlaybackState.playing);
    expect(player.loadedSegments, hasLength(1));
    expect(player.playCount, 1);
    expect(controller.currentCharacterStart, 0);

    controller.dispose();
  });

  test(
    'word timing cues update exact document highlighting positions',
    () async {
      final player = FakeCloudNarrationAudioPlayer();
      final controller = createController(player);

      await controller.start(text: text, voice: voice, rate: 0.8);
      final segment = controller.activeSegment!;
      player.reportPosition(const Duration(milliseconds: 1200));

      expect(
        controller.currentCharacterStart,
        segment.audioSegment.timingCues.last.startCharacter,
      );
      expect(
        controller.currentCharacterEnd,
        segment.audioSegment.timingCues.last.endCharacter,
      );
      expect(controller.progressPercent, greaterThan(0));

      controller.dispose();
    },
  );

  test('pause and resume delegate safely to the audio player', () async {
    final player = FakeCloudNarrationAudioPlayer();
    final controller = createController(player);

    await controller.start(text: text, voice: voice, rate: 0.8);
    await controller.pause();

    expect(controller.state, ReaderCloudNarrationPlaybackState.paused);
    expect(player.pauseCount, 1);

    await controller.resume();

    expect(controller.state, ReaderCloudNarrationPlaybackState.playing);
    expect(player.resumeCount, 1);

    controller.dispose();
  });

  test('completion emitted during resume advances safely', () async {
    final player = FakeCloudNarrationAudioPlayer();
    final controller = createController(player);

    await controller.start(text: text, voice: voice, rate: 0.8);
    await controller.pause();
    player.completeDuringResume = true;
    await controller.resume();
    await Future<void>.delayed(Duration.zero);

    expect(player.loadedSegments.length, greaterThanOrEqualTo(2));
    expect(controller.state, ReaderCloudNarrationPlaybackState.playing);

    controller.dispose();
  });

  test('completion automatically advances through prepared segments', () async {
    final player = FakeCloudNarrationAudioPlayer();
    final controller = createController(player);

    await controller.start(text: text, voice: voice, rate: 0.8);
    await Future<void>.delayed(Duration.zero);
    player.completeSegment();
    await Future<void>.delayed(Duration.zero);

    expect(player.loadedSegments.length, greaterThanOrEqualTo(2));
    expect(controller.state, ReaderCloudNarrationPlaybackState.playing);

    controller.dispose();
  });

  test('stop ignores a delayed completion callback', () async {
    final player = FakeCloudNarrationAudioPlayer();
    final controller = createController(player);

    await controller.start(text: text, voice: voice, rate: 0.8);
    await controller.stop();
    final loadCountAfterStop = player.loadedSegments.length;
    player.completeSegment();
    await Future<void>.delayed(Duration.zero);

    expect(controller.state, ReaderCloudNarrationPlaybackState.stopped);
    expect(player.loadedSegments, hasLength(loadCountAfterStop));

    controller.dispose();
  });

  test('stop callback emitted during stop cannot advance old audio', () async {
    final player = FakeCloudNarrationAudioPlayer();
    final controller = createController(player);

    await controller.start(text: text, voice: voice, rate: 0.8);
    final loadCountBeforeStop = player.loadedSegments.length;
    player.completeDuringStop = true;
    await controller.stop();

    expect(controller.state, ReaderCloudNarrationPlaybackState.stopped);
    expect(player.loadedSegments.length, loadCountBeforeStop);

    controller.dispose();
  });

  test('audio player errors remain isolated in the cloud controller', () async {
    final player = FakeCloudNarrationAudioPlayer();
    final controller = createController(player);

    await controller.start(text: text, voice: voice, rate: 0.8);
    player.reportError('Protected audio could not play.');

    expect(controller.state, ReaderCloudNarrationPlaybackState.error);
    expect(controller.errorMessage, 'Protected audio could not play.');
    expect(controller.queue.bufferedSegmentCount, 0);

    controller.dispose();
  });
}

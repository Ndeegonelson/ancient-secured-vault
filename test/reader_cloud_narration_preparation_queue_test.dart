import 'dart:async';
import 'dart:typed_data';

import 'package:ancient_secure_docs/services/reader_cloud_narration_preparation_queue.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_provider.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_registry.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_text_planner.dart';
import 'package:ancient_secure_docs/services/reader_narration_voice.dart';
import 'package:flutter_test/flutter_test.dart';

class QueueTestCloudProvider implements ReaderCloudNarrationProvider {
  QueueTestCloudProvider({
    this.delayFirstRequest,
    this.failAtStartCharacter,
    this.audioByteLength = 1,
  });

  final Completer<void>? delayFirstRequest;
  final int? failAtStartCharacter;
  final int audioByteLength;
  final List<ReaderCloudNarrationSynthesisRequest> requests = [];

  @override
  String get key => 'queue-provider';

  @override
  String get displayName => 'Queue Provider';

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
    requests.add(request);
    if (requests.length == 1 && delayFirstRequest != null) {
      await delayFirstRequest!.future;
    }
    if (request.startCharacter == failAtStartCharacter) {
      throw StateError('Provider request failed safely.');
    }

    return ReaderCloudNarrationAudioSegment(
      audioBytes: Uint8List(audioByteLength),
      contentType: 'audio/mpeg',
      startCharacter: request.startCharacter,
      endCharacter: request.endCharacter,
    );
  }
}

void main() {
  const voice = ReaderNarrationVoice(
    name: 'Ama',
    locale: 'en-GH',
    provider: ReaderNarrationVoiceProvider.cloudAi,
    providerKey: 'queue-provider',
  );
  const text = 'First sentence. Second sentence. Third sentence.';

  ReaderCloudNarrationPreparationQueue queueFor(
    QueueTestCloudProvider provider, {
    int maximumBufferedSegments = 2,
    int maximumBufferedAudioBytes = 8 * 1024 * 1024,
  }) {
    return ReaderCloudNarrationPreparationQueue(
      registry: ReaderCloudNarrationRegistry(providers: [provider]),
      planner: const ReaderCloudNarrationTextPlanner(
        maximumSegmentCharacters: 18,
      ),
      maximumBufferedSegments: maximumBufferedSegments,
      maximumBufferedAudioBytes: maximumBufferedAudioBytes,
    );
  }

  test('prepares a bounded ordered in-memory audio buffer', () async {
    final provider = QueueTestCloudProvider();
    final queue = queueFor(provider);

    queue.start(text: text, voice: voice, rate: 0.8);
    await queue.prepareBuffer();

    expect(queue.state, ReaderCloudNarrationPreparationState.ready);
    expect(queue.bufferedSegmentCount, 2);
    expect(queue.bufferedAudioByteCount, 2);
    expect(provider.requests, hasLength(2));

    final first = queue.takeNext()!;
    final second = queue.takeNext()!;

    expect(first.textSegment.index, 0);
    expect(second.textSegment.index, 1);
    expect(first.audioSegment.endCharacter, second.audioSegment.startCharacter);
    expect(queue.bufferedSegmentCount, 0);
    expect(queue.bufferedAudioByteCount, 0);
  });

  test(
    'consumed audio is released before preparing the next segment',
    () async {
      final provider = QueueTestCloudProvider();
      final queue = queueFor(provider, maximumBufferedSegments: 1);

      queue.start(text: text, voice: voice, rate: 0.8);
      await queue.prepareBuffer();
      final first = queue.takeNext();
      await queue.prepareBuffer();

      expect(first, isNotNull);
      expect(queue.bufferedSegmentCount, 1);
      expect(provider.requests, hasLength(2));
    },
  );

  test('late provider response is discarded after cancellation', () async {
    final delayedRequest = Completer<void>();
    final provider = QueueTestCloudProvider(delayFirstRequest: delayedRequest);
    final queue = queueFor(provider);

    queue.start(text: text, voice: voice, rate: 0.8);
    final preparation = queue.prepareBuffer();
    await Future<void>.delayed(Duration.zero);
    queue.cancel();
    delayedRequest.complete();
    await preparation;

    expect(queue.state, ReaderCloudNarrationPreparationState.cancelled);
    expect(queue.bufferedSegmentCount, 0);
    expect(queue.hasPreparedSegment, isFalse);
  });

  test(
    'new session invalidates audio from an older voice or document',
    () async {
      final delayedRequest = Completer<void>();
      final provider = QueueTestCloudProvider(
        delayFirstRequest: delayedRequest,
      );
      final queue = queueFor(provider);

      queue.start(text: text, voice: voice, rate: 0.8);
      final oldPreparation = queue.prepareBuffer();
      await Future<void>.delayed(Duration.zero);
      queue.start(text: 'New document.', voice: voice, rate: 1);
      delayedRequest.complete();
      await oldPreparation;
      await queue.prepareBuffer();

      expect(queue.bufferedSegmentCount, 1);
      expect(queue.takeNext()!.textSegment.text, 'New document.');
    },
  );

  test('provider failure remains isolated and recoverable', () async {
    final failingProvider = QueueTestCloudProvider(failAtStartCharacter: 0);
    final queue = queueFor(failingProvider);

    queue.start(text: text, voice: voice, rate: 0.8);
    await queue.prepareBuffer();

    expect(queue.state, ReaderCloudNarrationPreparationState.error);
    expect(queue.bufferedSegmentCount, 0);
    expect(queue.errorMessage, 'Provider request failed safely.');

    final healthyProvider = QueueTestCloudProvider();
    final recoveredQueue = queueFor(healthyProvider);
    recoveredQueue.start(text: text, voice: voice, rate: 0.8);
    await recoveredQueue.prepareBuffer();

    expect(recoveredQueue.state, ReaderCloudNarrationPreparationState.ready);
  });

  test(
    'oversized provider audio is rejected by the secure memory limit',
    () async {
      final provider = QueueTestCloudProvider(audioByteLength: 5);
      final queue = queueFor(provider, maximumBufferedAudioBytes: 4);

      queue.start(text: text, voice: voice, rate: 0.8);
      await queue.prepareBuffer();

      expect(queue.state, ReaderCloudNarrationPreparationState.error);
      expect(queue.bufferedAudioByteCount, 0);
      expect(
        queue.errorMessage,
        'Cloud narration segment exceeds the secure memory limit.',
      );
    },
  );
}

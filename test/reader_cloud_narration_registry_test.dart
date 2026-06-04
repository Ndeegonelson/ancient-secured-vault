import 'dart:typed_data';

import 'package:ancient_secure_docs/services/reader_cloud_narration_provider.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_registry.dart';
import 'package:ancient_secure_docs/services/reader_narration_voice.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCloudNarrationProvider implements ReaderCloudNarrationProvider {
  FakeCloudNarrationProvider({
    required this.key,
    required this.displayName,
    required this.status,
    this.voices = const [],
    this.shouldThrow = false,
    this.synthesisResult,
  });

  @override
  final String key;

  @override
  final String displayName;

  final ReaderCloudNarrationProviderStatus status;
  final List<ReaderNarrationVoice> voices;
  final bool shouldThrow;
  ReaderCloudNarrationAudioSegment? synthesisResult;
  ReaderCloudNarrationSynthesisRequest? lastRequest;

  @override
  ReaderCloudNarrationProviderCapabilities get capabilities =>
      const ReaderCloudNarrationProviderCapabilities(
        supportsStreamingAudio: true,
        supportsWordTimings: true,
        supportsVoiceStyles: true,
        supportsCustomVoices: true,
      );

  @override
  Future<ReaderCloudNarrationProviderStatus> checkStatus() async {
    if (shouldThrow) throw Exception('Provider unavailable');
    return status;
  }

  @override
  Future<List<ReaderNarrationVoice>> loadVoices() async => voices;

  @override
  Future<ReaderCloudNarrationAudioSegment> synthesize(
    ReaderCloudNarrationSynthesisRequest request,
  ) async {
    lastRequest = request;
    return synthesisResult ??
        ReaderCloudNarrationAudioSegment(
          audioBytes: Uint8List.fromList([1, 2, 3]),
          contentType: 'audio/mpeg',
          startCharacter: request.startCharacter,
          endCharacter: request.endCharacter,
          timingCues: const [
            ReaderCloudNarrationTimingCue(
              startCharacter: 4,
              endCharacter: 11,
              audioOffset: Duration(milliseconds: 250),
            ),
          ],
        );
  }
}

void main() {
  const readyStatus = ReaderCloudNarrationProviderStatus(
    state: ReaderCloudNarrationProviderState.ready,
    message: 'Ready',
  );

  test('empty registry keeps browser narration independent', () async {
    const registry = ReaderCloudNarrationRegistry();

    final catalog = await registry.loadCatalog();

    expect(catalog.voices, isEmpty);
    expect(catalog.providerStatuses, isEmpty);
    expect(catalog.hasReadyProvider, isFalse);
  });

  test(
    'catalog normalizes future cloud voice ownership and metadata',
    () async {
      final provider = FakeCloudNarrationProvider(
        key: 'future-provider',
        displayName: 'Future Provider',
        status: readyStatus,
        voices: const [
          ReaderNarrationVoice(
            name: 'Ama',
            locale: 'en-GH',
            accent: 'Ghanaian',
            gender: 'Female',
          ),
        ],
      );
      final registry = ReaderCloudNarrationRegistry(providers: [provider]);

      final catalog = await registry.loadCatalog();
      final voice = catalog.voices.single;

      expect(catalog.hasReadyProvider, isTrue);
      expect(voice.provider, ReaderNarrationVoiceProvider.cloudAi);
      expect(voice.providerKey, 'future-provider');
      expect(voice.id, 'cloudAi|future-provider|en-GH|Ama');
      expect(voice.label, 'Ama | en-GH | Ghanaian | Female');
    },
  );

  test('provider failure is isolated from the narration catalog', () async {
    final provider = FakeCloudNarrationProvider(
      key: 'future-provider',
      displayName: 'Future Provider',
      status: readyStatus,
      shouldThrow: true,
    );
    final registry = ReaderCloudNarrationRegistry(providers: [provider]);

    final catalog = await registry.loadCatalog();

    expect(catalog.voices, isEmpty);
    expect(
      catalog.providerStatuses['future-provider']?.state,
      ReaderCloudNarrationProviderState.temporarilyUnavailable,
    );
  });

  test(
    'synthesis routes to the provider and returns in-memory audio',
    () async {
      final provider = FakeCloudNarrationProvider(
        key: 'future-provider',
        displayName: 'Future Provider',
        status: readyStatus,
      );
      final registry = ReaderCloudNarrationRegistry(providers: [provider]);
      const voice = ReaderNarrationVoice(
        name: 'Ama',
        locale: 'fr-GH',
        provider: ReaderNarrationVoiceProvider.cloudAi,
        providerKey: 'future-provider',
      );
      const request = ReaderCloudNarrationSynthesisRequest(
        text: 'Bonjour a tous.',
        voice: voice,
        rate: 0.8,
        startCharacter: 4,
      );

      final segment = await registry.synthesize(request);

      expect(provider.lastRequest, same(request));
      expect(segment.audioBytes, [1, 2, 3]);
      expect(segment.contentType, 'audio/mpeg');
      expect(segment.startCharacter, 4);
      expect(segment.endCharacter, request.endCharacter);
      expect(segment.isEmpty, isFalse);
      expect(segment.timingCues.single.startCharacter, 4);
      expect(
        segment.timingCues.single.audioOffset,
        const Duration(milliseconds: 250),
      );
      expect(provider.capabilities.supportsWordTimings, isTrue);
    },
  );

  test('invalid provider audio is rejected before playback', () async {
    final provider = FakeCloudNarrationProvider(
      key: 'future-provider',
      displayName: 'Future Provider',
      status: readyStatus,
      synthesisResult: ReaderCloudNarrationAudioSegment(
        audioBytes: Uint8List(0),
        contentType: 'audio/mpeg',
        startCharacter: 0,
        endCharacter: 0,
      ),
    );
    final registry = ReaderCloudNarrationRegistry(providers: [provider]);
    const request = ReaderCloudNarrationSynthesisRequest(
      text: 'Protected narration text.',
      voice: ReaderNarrationVoice(
        name: 'Ama',
        locale: 'en-GH',
        provider: ReaderNarrationVoiceProvider.cloudAi,
        providerKey: 'future-provider',
      ),
      rate: 0.8,
    );

    expect(() => registry.synthesize(request), throwsA(isA<StateError>()));
  });

  test('out-of-order timing cues are rejected before playback', () async {
    final provider = FakeCloudNarrationProvider(
      key: 'future-provider',
      displayName: 'Future Provider',
      status: readyStatus,
      synthesisResult: ReaderCloudNarrationAudioSegment(
        audioBytes: Uint8List.fromList([1]),
        contentType: 'audio/mpeg',
        startCharacter: 0,
        endCharacter: 9,
        timingCues: const [
          ReaderCloudNarrationTimingCue(
            startCharacter: 0,
            endCharacter: 4,
            audioOffset: Duration(seconds: 1),
          ),
          ReaderCloudNarrationTimingCue(
            startCharacter: 4,
            endCharacter: 9,
            audioOffset: Duration(milliseconds: 500),
          ),
        ],
      ),
    );
    final registry = ReaderCloudNarrationRegistry(providers: [provider]);
    const request = ReaderCloudNarrationSynthesisRequest(
      text: 'Narration',
      voice: ReaderNarrationVoice(
        name: 'Ama',
        locale: 'en-GH',
        provider: ReaderNarrationVoiceProvider.cloudAi,
        providerKey: 'future-provider',
      ),
      rate: 0.8,
    );

    expect(() => registry.synthesize(request), throwsA(isA<StateError>()));
  });

  test('non-audio provider content is rejected before playback', () async {
    final provider = FakeCloudNarrationProvider(
      key: 'future-provider',
      displayName: 'Future Provider',
      status: readyStatus,
      synthesisResult: ReaderCloudNarrationAudioSegment(
        audioBytes: Uint8List.fromList([1]),
        contentType: 'text/plain',
        startCharacter: 0,
        endCharacter: 9,
      ),
    );
    final registry = ReaderCloudNarrationRegistry(providers: [provider]);
    const request = ReaderCloudNarrationSynthesisRequest(
      text: 'Narration',
      voice: ReaderNarrationVoice(
        name: 'Ama',
        locale: 'en-GH',
        provider: ReaderNarrationVoiceProvider.cloudAi,
        providerKey: 'future-provider',
      ),
      rate: 0.8,
    );

    expect(() => registry.synthesize(request), throwsA(isA<StateError>()));
  });
}

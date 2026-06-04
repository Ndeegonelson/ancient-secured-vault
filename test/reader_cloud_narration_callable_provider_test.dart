import 'dart:convert';

import 'package:ancient_secure_docs/services/reader_cloud_narration_callable_provider.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_provider.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_registry.dart';
import 'package:ancient_secure_docs/services/reader_narration_voice.dart';
import 'package:flutter_test/flutter_test.dart';

class TestCallableClient implements ReaderCloudNarrationCallableClient {
  TestCallableClient({required this.responses});

  final Map<String, Map<String, dynamic>> responses;
  final List<({String functionName, Map<String, dynamic> data})> calls = [];

  @override
  Future<Map<String, dynamic>> call(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    calls.add((functionName: functionName, data: Map.unmodifiable(data)));
    final response = responses[functionName];
    if (response == null) {
      throw StateError('No test response for $functionName.');
    }

    return response;
  }
}

class TestReadinessCallableClient extends TestCallableClient
    implements ReaderCloudNarrationCallableReadinessClient {
  TestReadinessCallableClient({
    required super.responses,
    required this.readiness,
  });

  final ReaderCloudNarrationCallableReadiness readiness;

  @override
  Future<ReaderCloudNarrationCallableReadiness> checkReadiness() async {
    return readiness;
  }
}

void main() {
  test(
    'loads backend-approved cloud voices without exposing provider internals',
    () async {
      final client = TestCallableClient(
        responses: {
          'cloudNarrationCatalog': {
            'status': 'ready',
            'voices': [
              {
                'id': 'demo-provider:demo-secure-narrator',
                'name': 'Demo Secure Narrator',
                'locale': 'en-GH',
                'accent': 'Neutral African',
                'gender': 'Demo',
                'style': 'Architecture test',
                'isCustom': false,
                'privateProviderSetting': 'must not enter Flutter',
              },
            ],
          },
        },
      );
      final realProvider = ReaderCloudNarrationCallableProvider(client: client);

      final voices = await realProvider.loadVoices();
      final voice = voices.single;

      expect(realProvider.key, 'firebase-functions');
      expect(client.calls.single.functionName, 'cloudNarrationCatalog');
      expect(client.calls.single.data, isEmpty);
      expect(voice.name, 'Demo Secure Narrator');
      expect(voice.locale, 'en-GH');
      expect(voice.accent, 'Neutral African');
      expect(voice.gender, 'Demo');
      expect(voice.style, 'Architecture test');
      expect(voice.cloudVoiceId, 'demo-provider:demo-secure-narrator');
      expect(voice.provider, ReaderNarrationVoiceProvider.cloudAi);
      expect(voice.providerKey, 'firebase-functions');
      expect(
        voice.id,
        'cloudAi|firebase-functions|demo-provider:demo-secure-narrator',
      );
    },
  );

  test('not configured backend catalog returns no cloud voices', () async {
    final client = TestCallableClient(
      responses: {
        'cloudNarrationCatalog': {'status': 'notConfigured', 'voices': []},
      },
    );
    final provider = ReaderCloudNarrationCallableProvider(client: client);

    final voices = await provider.loadVoices();

    expect(voices, isEmpty);
  });

  test(
    'reports unavailable before loading catalog when security is not ready',
    () async {
      final client = TestReadinessCallableClient(
        responses: {
          'cloudNarrationCatalog': {'status': 'ready', 'voices': const []},
        },
        readiness: const ReaderCloudNarrationCallableReadiness.unavailable(
          message: 'Secure cloud narration is waiting for App Check setup.',
        ),
      );
      final provider = ReaderCloudNarrationCallableProvider(client: client);
      final registry = ReaderCloudNarrationRegistry(providers: [provider]);

      final catalog = await registry.loadCatalog();
      final status = catalog.providerStatuses[provider.key];

      expect(
        status?.state,
        ReaderCloudNarrationProviderState.temporarilyUnavailable,
      );
      expect(
        status?.message,
        'Secure cloud narration is waiting for App Check setup.',
      );
      expect(catalog.voices, isEmpty);
      expect(client.calls, isEmpty);
    },
  );

  test('sends only approved backend voice id for synthesis', () async {
    final audioBytes = [82, 73, 70, 70];
    final client = TestCallableClient(
      responses: {
        'synthesizeCloudNarration': {
          'audioBase64': base64Encode(audioBytes),
          'contentType': 'audio/wav',
          'startCharacter': 12,
          'endCharacter': 20,
          'durationMilliseconds': 800,
          'usage': {
            'dateKey': '2026-06-04',
            'plan': 'premium',
            'usedCharacters': 8,
            'usedRequests': 1,
            'remainingCharacters': 119992,
            'remainingRequests': 99,
            'privateQuotaPath': 'must not reach Flutter',
          },
          'timingCues': [
            {
              'startCharacter': 12,
              'endCharacter': 19,
              'audioOffsetMilliseconds': 0,
            },
          ],
        },
      },
    );
    final provider = ReaderCloudNarrationCallableProvider(client: client);
    const voice = ReaderNarrationVoice(
      name: 'Demo Secure Narrator',
      locale: 'en-GH',
      cloudVoiceId: 'demo-provider:demo-secure-narrator',
      provider: ReaderNarrationVoiceProvider.cloudAi,
      providerKey: 'firebase-functions',
    );
    const request = ReaderCloudNarrationSynthesisRequest(
      text: 'Bonjour.',
      voice: voice,
      rate: 0.8,
      startCharacter: 12,
    );

    final segment = await provider.synthesize(request);

    expect(client.calls.single.functionName, 'synthesizeCloudNarration');
    expect(client.calls.single.data, {
      'text': 'Bonjour.',
      'voiceId': 'demo-provider:demo-secure-narrator',
      'rate': 0.8,
      'startCharacter': 12,
    });
    expect(segment.audioBytes, audioBytes);
    expect(segment.contentType, 'audio/wav');
    expect(segment.startCharacter, 12);
    expect(segment.endCharacter, 20);
    expect(segment.duration, const Duration(milliseconds: 800));
    expect(segment.usage?.dateKey, '2026-06-04');
    expect(segment.usage?.plan, 'premium');
    expect(segment.usage?.usedCharacters, 8);
    expect(segment.usage?.usedRequests, 1);
    expect(segment.usage?.remainingCharacters, 119992);
    expect(segment.usage?.remainingRequests, 99);
    expect(segment.timingCues.single.startCharacter, 12);
    expect(segment.timingCues.single.audioOffset, Duration.zero);
    expect(segment.isValidFor(request), isTrue);
  });

  test(
    'registry can use callable provider as a normal secure cloud provider',
    () async {
      final client = TestCallableClient(
        responses: {
          'cloudNarrationCatalog': {
            'status': 'ready',
            'voices': [
              {
                'id': 'demo-provider:demo-secure-narrator',
                'name': 'Demo Secure Narrator',
                'locale': 'en-GH',
              },
            ],
          },
          'synthesizeCloudNarration': {
            'audioBase64': base64Encode([1]),
            'contentType': 'audio/wav',
            'startCharacter': 0,
            'endCharacter': 5,
          },
        },
      );
      final provider = ReaderCloudNarrationCallableProvider(client: client);
      final registry = ReaderCloudNarrationRegistry(providers: [provider]);

      final catalog = await registry.loadCatalog();
      final voice = catalog.voices.single;
      final segment = await registry.synthesize(
        ReaderCloudNarrationSynthesisRequest(
          text: 'Hello',
          voice: voice,
          rate: 1,
        ),
      );

      expect(catalog.hasReadyProvider, isTrue);
      expect(voice.cloudVoiceId, 'demo-provider:demo-secure-narrator');
      expect(voice.providerKey, 'firebase-functions');
      expect(segment.audioBytes, [1]);
    },
  );

  test(
    'rejects synthesis when the voice is missing backend approval id',
    () async {
      final provider = ReaderCloudNarrationCallableProvider(
        client: TestCallableClient(responses: const {}),
      );
      const voice = ReaderNarrationVoice(
        name: 'Unapproved',
        locale: 'en-GH',
        provider: ReaderNarrationVoiceProvider.cloudAi,
        providerKey: 'firebase-functions',
      );

      await expectLater(
        provider.synthesize(
          const ReaderCloudNarrationSynthesisRequest(
            text: 'Hello',
            voice: voice,
            rate: 1,
          ),
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('rejects invalid backend audio before playback', () async {
    final provider = ReaderCloudNarrationCallableProvider(
      client: TestCallableClient(
        responses: {
          'synthesizeCloudNarration': {
            'audioBase64': 'not base64',
            'contentType': 'audio/wav',
            'startCharacter': 0,
            'endCharacter': 5,
          },
        },
      ),
    );
    const voice = ReaderNarrationVoice(
      name: 'Demo Secure Narrator',
      locale: 'en-GH',
      cloudVoiceId: 'demo-provider:demo-secure-narrator',
      provider: ReaderNarrationVoiceProvider.cloudAi,
      providerKey: 'firebase-functions',
    );

    await expectLater(
      provider.synthesize(
        const ReaderCloudNarrationSynthesisRequest(
          text: 'Hello',
          voice: voice,
          rate: 1,
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });
}

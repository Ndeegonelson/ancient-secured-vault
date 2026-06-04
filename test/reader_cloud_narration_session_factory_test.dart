import 'dart:convert';

import 'package:ancient_secure_docs/services/reader_cloud_narration_audio_player.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_callable_provider.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_provider.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_session_coordinator.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_session_factory.dart';
import 'package:ancient_secure_docs/services/reader_cloud_narration_text_planner.dart';
import 'package:ancient_secure_docs/services/reader_narration_access_policy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class FactoryTestCallableClient implements ReaderCloudNarrationCallableClient {
  FactoryTestCallableClient({required this.responses});

  final Map<String, Map<String, dynamic>> responses;
  final List<String> functionCalls = [];

  @override
  Future<Map<String, dynamic>> call(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    functionCalls.add(functionName);
    final response = responses[functionName];
    if (response == null) {
      throw StateError('No response for $functionName.');
    }

    return response;
  }
}

class FactoryTestAudioPlayer implements ReaderCloudNarrationAudioPlayer {
  ReaderCloudNarrationAudioSegment? loadedSegment;
  int playCount = 0;
  bool disposed = false;

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  Future<void> load(ReaderCloudNarrationAudioSegment segment) async {
    loadedSegment = segment;
  }

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

ReaderNarrationAccessPolicy policy({
  bool isAdmin = false,
  bool hasActiveSubscription = true,
}) {
  return ReaderNarrationAccessPolicy.fromUserAccess(
    isAdmin: isAdmin,
    hasActiveSubscription: hasActiveSubscription,
  );
}

void main() {
  test(
    'creates a ready cloud narration coordinator from callable backend',
    () async {
      final audioPlayer = FactoryTestAudioPlayer();
      final client = FactoryTestCallableClient(
        responses: {
          'cloudNarrationCatalog': {
            'status': 'ready',
            'voices': [
              {
                'id': 'demo-provider:african-english',
                'name': 'African English Narrator',
                'locale': 'en-GH',
                'accent': 'African',
              },
            ],
          },
          'synthesizeCloudNarration': {
            'audioBase64': base64Encode([1, 2, 3]),
            'contentType': 'audio/wav',
            'startCharacter': 0,
            'endCharacter': 20,
            'durationMilliseconds': 1000,
          },
        },
      );
      final factory = ReaderCloudNarrationSessionFactory(
        client: client,
        audioPlayerBuilder: () => audioPlayer,
        textPlanner: const ReaderCloudNarrationTextPlanner(
          maximumSegmentCharacters: 60,
        ),
      );
      final coordinator = factory.createCoordinator(accessPolicy: policy());

      final ready = await coordinator.refreshCatalog();
      await coordinator.selectVoice(coordinator.availableVoices.single);
      final started = await coordinator.start(
        text: 'Protected narration text for the cloud provider.',
        rate: 1,
      );

      expect(ready, isTrue);
      expect(coordinator.state, ReaderCloudNarrationSessionState.playing);
      expect(
        coordinator.availableVoices.single.name,
        'African English Narrator',
      );
      expect(client.functionCalls, [
        'cloudNarrationCatalog',
        'synthesizeCloudNarration',
      ]);
      expect(started, isTrue);
      expect(audioPlayer.loadedSegment?.audioBytes, [1, 2, 3]);
      expect(audioPlayer.playCount, 1);

      coordinator.dispose();
    },
  );

  test('uses access policy before loading callable cloud catalog', () async {
    final client = FactoryTestCallableClient(
      responses: {
        'cloudNarrationCatalog': {'status': 'ready', 'voices': const []},
      },
    );
    final factory = ReaderCloudNarrationSessionFactory(
      client: client,
      audioPlayerBuilder: FactoryTestAudioPlayer.new,
    );
    final coordinator = factory.createCoordinator(
      accessPolicy: policy(hasActiveSubscription: false),
    );

    final ready = await coordinator.refreshCatalog();

    expect(ready, isFalse);
    expect(coordinator.state, ReaderCloudNarrationSessionState.accessDenied);
    expect(client.functionCalls, isEmpty);

    coordinator.dispose();
  });
}

import 'dart:async';

import 'package:ancient_secure_docs/services/reader_cloud_narration_provider.dart';
import 'package:ancient_secure_docs/services/reader_temporary_audio_platform.dart';
import 'package:ancient_secure_docs/services/reader_temporary_cloud_narration_audio_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTemporaryAudioPlatform implements ReaderTemporaryAudioPlatform {
  ValueChanged<Duration>? positionHandler;
  VoidCallback? completionHandler;
  ValueChanged<String>? errorHandler;
  final List<String> createdUrls = [];
  final List<String> revokedUrls = [];
  final List<String> loadedUrls = [];
  int clearCount = 0;
  int playCount = 0;
  int pauseCount = 0;
  int resumeCount = 0;
  int stopCount = 0;
  int disposeCount = 0;
  bool failLoad = false;
  Completer<void>? delayedLoad;

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
  String createObjectUrl(Uint8List audioBytes, String contentType) {
    final objectUrl = 'blob:protected-${createdUrls.length + 1}';
    createdUrls.add(objectUrl);
    return objectUrl;
  }

  @override
  void revokeObjectUrl(String objectUrl) {
    revokedUrls.add(objectUrl);
  }

  @override
  Future<void> loadSource(String objectUrl) async {
    loadedUrls.add(objectUrl);
    await delayedLoad?.future;
    if (failLoad) throw StateError('Temporary audio load failed.');
  }

  @override
  Future<void> clearSource() async {
    clearCount++;
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
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
  }

  void complete() => completionHandler?.call();

  void reportPosition(Duration position) => positionHandler?.call(position);

  void reportError(String message) => errorHandler?.call(message);
}

void main() {
  ReaderCloudNarrationAudioSegment segment(int value) {
    return ReaderCloudNarrationAudioSegment(
      audioBytes: Uint8List.fromList([value]),
      contentType: 'audio/mpeg',
      startCharacter: value,
      endCharacter: value + 1,
    );
  }

  test('replacing audio revokes the previous temporary object URL', () async {
    final platform = FakeTemporaryAudioPlatform();
    final player = ReaderTemporaryCloudNarrationAudioPlayer(platform: platform);

    await player.load(segment(1));
    await player.load(segment(2));

    expect(platform.createdUrls, ['blob:protected-1', 'blob:protected-2']);
    expect(platform.revokedUrls, ['blob:protected-1']);
    expect(player.hasActiveObjectUrl, isTrue);

    await player.dispose();
  });

  test('completion releases audio before notifying the controller', () async {
    final platform = FakeTemporaryAudioPlatform();
    final player = ReaderTemporaryCloudNarrationAudioPlayer(platform: platform);
    bool releasedBeforeCompletion = false;

    player.setCompletionHandler(() {
      releasedBeforeCompletion = !player.hasActiveObjectUrl;
    });
    await player.load(segment(1));
    platform.complete();
    await Future<void>.delayed(Duration.zero);

    expect(releasedBeforeCompletion, isTrue);
    expect(platform.revokedUrls, ['blob:protected-1']);

    await player.dispose();
  });

  test('stop clears and revokes the active protected audio', () async {
    final platform = FakeTemporaryAudioPlatform();
    final player = ReaderTemporaryCloudNarrationAudioPlayer(platform: platform);

    await player.load(segment(1));
    await player.stop();

    expect(player.hasActiveObjectUrl, isFalse);
    expect(platform.stopCount, 1);
    expect(platform.revokedUrls, ['blob:protected-1']);

    await player.dispose();
  });

  test('late completion and error callbacks after stop are ignored', () async {
    final platform = FakeTemporaryAudioPlatform();
    final player = ReaderTemporaryCloudNarrationAudioPlayer(platform: platform);
    int completionCount = 0;
    String? errorMessage;

    player.setCompletionHandler(() => completionCount++);
    player.setErrorHandler((message) => errorMessage = message);
    await player.load(segment(1));
    await player.stop();
    platform.complete();
    platform.reportError('Late browser error');
    await Future<void>.delayed(Duration.zero);

    expect(completionCount, 0);
    expect(errorMessage, isNull);

    await player.dispose();
  });

  test('failed load still revokes its temporary URL', () async {
    final platform = FakeTemporaryAudioPlatform()..failLoad = true;
    final player = ReaderTemporaryCloudNarrationAudioPlayer(platform: platform);

    await expectLater(player.load(segment(1)), throwsA(isA<StateError>()));

    expect(player.hasActiveObjectUrl, isFalse);
    expect(platform.revokedUrls, ['blob:protected-1']);

    await player.dispose();
  });

  test('stop invalidates an audio source that is still loading', () async {
    final delayedLoad = Completer<void>();
    final platform = FakeTemporaryAudioPlatform()..delayedLoad = delayedLoad;
    final player = ReaderTemporaryCloudNarrationAudioPlayer(platform: platform);

    final loading = player.load(segment(1));
    await Future<void>.delayed(Duration.zero);
    await player.stop();
    delayedLoad.complete();
    await loading;

    expect(player.hasActiveObjectUrl, isFalse);
    expect(platform.revokedUrls, ['blob:protected-1']);

    await player.dispose();
  });

  test(
    'position and error callbacks pass through the protected player',
    () async {
      final platform = FakeTemporaryAudioPlatform();
      final player = ReaderTemporaryCloudNarrationAudioPlayer(
        platform: platform,
      );
      Duration? reportedPosition;
      String? reportedError;

      player.setPositionHandler((position) => reportedPosition = position);
      player.setErrorHandler((message) => reportedError = message);
      await player.load(segment(1));
      platform.reportPosition(const Duration(milliseconds: 750));
      platform.reportError('Audio error');

      expect(reportedPosition, const Duration(milliseconds: 750));
      expect(reportedError, 'Audio error');

      await player.dispose();
    },
  );

  test('dispose revokes active audio and disposes the platform', () async {
    final platform = FakeTemporaryAudioPlatform();
    final player = ReaderTemporaryCloudNarrationAudioPlayer(platform: platform);

    await player.load(segment(1));
    await player.dispose();

    expect(player.hasActiveObjectUrl, isFalse);
    expect(platform.revokedUrls, ['blob:protected-1']);
    expect(platform.disposeCount, 1);
  });
}

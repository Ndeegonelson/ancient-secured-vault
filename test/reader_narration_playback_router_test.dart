import 'package:ancient_secure_docs/services/reader_cloud_narration_provider.dart';
import 'package:ancient_secure_docs/services/reader_narration_access_policy.dart';
import 'package:ancient_secure_docs/services/reader_narration_playback_plan.dart';
import 'package:ancient_secure_docs/services/reader_narration_playback_router.dart';
import 'package:ancient_secure_docs/services/reader_narration_playback_snapshot.dart';
import 'package:ancient_secure_docs/services/reader_narration_voice.dart';
import 'package:ancient_secure_docs/services/reader_narration_voice_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

class RouterTestBrowserDelegate implements ReaderBrowserNarrationDelegate {
  ReaderNarrationVoice? selectedVoice;
  int starts = 0;
  int pauses = 0;
  int resumes = 0;
  int stops = 0;
  bool startResult = true;
  bool resumeResult = true;

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
    starts++;
    return startResult;
  }

  @override
  Future<void> pauseBrowserNarration() async {
    pauses++;
  }

  @override
  Future<bool> resumeBrowserNarration() async {
    resumes++;
    return resumeResult;
  }

  @override
  Future<void> stopBrowserNarration() async {
    stops++;
  }
}

class RouterTestCloudDelegate implements ReaderCloudNarrationDelegate {
  ReaderNarrationVoice? selectedVoice;
  int starts = 0;
  int pauses = 0;
  int resumes = 0;
  int stops = 0;
  bool selectResult = true;
  bool startResult = true;

  @override
  Future<bool> selectCloudVoice(ReaderNarrationVoice voice) async {
    selectedVoice = voice;
    return selectResult;
  }

  @override
  Future<bool> startCloudNarration({
    required String text,
    required double rate,
    required int startCharacter,
  }) async {
    starts++;
    return startResult;
  }

  @override
  Future<void> pauseCloudNarration() async {
    pauses++;
  }

  @override
  Future<void> resumeCloudNarration() async {
    resumes++;
  }

  @override
  Future<void> stopCloudNarration() async {
    stops++;
  }
}

const browserVoice = ReaderNarrationVoice(
  name: 'Microsoft David',
  locale: 'en-US',
);

const cloudVoice = ReaderNarrationVoice(
  name: 'African English Guide',
  locale: 'en-GH',
  accent: 'African',
  cloudVoiceId: 'demo-provider:african-english',
  provider: ReaderNarrationVoiceProvider.cloudAi,
  providerKey: 'firebase-functions',
);

ReaderNarrationAccessPolicy policy({bool premium = true}) {
  return ReaderNarrationAccessPolicy.fromUserAccess(
    isAdmin: false,
    hasActiveSubscription: premium,
  );
}

ReaderNarrationPlaybackSnapshot snapshotFor({
  required ReaderNarrationVoice voice,
  bool canStart = true,
}) {
  final catalog = ReaderNarrationVoiceCatalog(
    accessPolicy: policy(),
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
    providerStatuses: const {
      'firebase-functions': ReaderCloudNarrationProviderStatus(
        state: ReaderCloudNarrationProviderState.ready,
        message: 'Ready',
      ),
    },
  );
  final plan = canStart
      ? ReaderNarrationPlaybackPlan.ready(
          engine: voice.provider == ReaderNarrationVoiceProvider.cloudAi
              ? ReaderNarrationPlaybackEngine.cloud
              : ReaderNarrationPlaybackEngine.browser,
          voice: voice,
          message: 'Ready',
        )
      : ReaderNarrationPlaybackPlan.unavailable('No narrator.');

  return ReaderNarrationPlaybackSnapshot(catalog: catalog, plan: plan);
}

ReaderNarrationPlaybackStartRequest requestFor(
  ReaderNarrationPlaybackSnapshot snapshot,
) {
  return ReaderNarrationPlaybackStartRequest(
    snapshot: snapshot,
    text: 'Protected narration text.',
    pageNumber: 3,
    rate: 0.8,
    startCharacter: 4,
  );
}

void main() {
  test('routes browser playback through browser delegate', () async {
    final browser = RouterTestBrowserDelegate();
    final cloud = RouterTestCloudDelegate();
    final router = ReaderNarrationPlaybackRouter(
      browserDelegate: browser,
      cloudDelegate: cloud,
    );

    final started = await router.start(
      requestFor(snapshotFor(voice: browserVoice)),
    );

    expect(started, isTrue);
    expect(router.activeEngine, ReaderNarrationPlaybackEngine.browser);
    expect(browser.selectedVoice, browserVoice);
    expect(browser.starts, 1);
    expect(cloud.stops, 1);
    expect(cloud.starts, 0);
  });

  test('routes cloud playback through cloud delegate', () async {
    final browser = RouterTestBrowserDelegate();
    final cloud = RouterTestCloudDelegate();
    final router = ReaderNarrationPlaybackRouter(
      browserDelegate: browser,
      cloudDelegate: cloud,
    );

    final started = await router.start(
      requestFor(snapshotFor(voice: cloudVoice)),
    );

    expect(started, isTrue);
    expect(router.activeEngine, ReaderNarrationPlaybackEngine.cloud);
    expect(router.isUsingCloud, isTrue);
    expect(browser.stops, 1);
    expect(browser.starts, 0);
    expect(cloud.selectedVoice, cloudVoice);
    expect(cloud.starts, 1);
  });

  test('does not start cloud plan when cloud delegate is missing', () async {
    final browser = RouterTestBrowserDelegate();
    final router = ReaderNarrationPlaybackRouter(browserDelegate: browser);

    final started = await router.start(
      requestFor(snapshotFor(voice: cloudVoice)),
    );

    expect(started, isFalse);
    expect(router.activeEngine, isNull);
    expect(router.errorMessage, 'Secure cloud narration is not connected yet.');
    expect(browser.starts, 0);
  });

  test('does not start unavailable plans', () async {
    final browser = RouterTestBrowserDelegate();
    final router = ReaderNarrationPlaybackRouter(browserDelegate: browser);

    final started = await router.start(
      requestFor(snapshotFor(voice: browserVoice, canStart: false)),
    );

    expect(started, isFalse);
    expect(router.errorMessage, 'No narrator.');
    expect(browser.starts, 0);
  });

  test('pause resume and stop follow the active browser engine', () async {
    final browser = RouterTestBrowserDelegate();
    final cloud = RouterTestCloudDelegate();
    final router = ReaderNarrationPlaybackRouter(
      browserDelegate: browser,
      cloudDelegate: cloud,
    );

    await router.start(requestFor(snapshotFor(voice: browserVoice)));
    await router.pause();
    final resumed = await router.resume();
    await router.stop();

    expect(resumed, isTrue);
    expect(browser.pauses, 1);
    expect(browser.resumes, 1);
    expect(browser.stops, 1);
    expect(cloud.pauses, 0);
    expect(router.activeEngine, isNull);
  });

  test('pause resume and stop follow the active cloud engine', () async {
    final browser = RouterTestBrowserDelegate();
    final cloud = RouterTestCloudDelegate();
    final router = ReaderNarrationPlaybackRouter(
      browserDelegate: browser,
      cloudDelegate: cloud,
    );

    await router.start(requestFor(snapshotFor(voice: cloudVoice)));
    await router.pause();
    final resumed = await router.resume();
    await router.stop();

    expect(resumed, isTrue);
    expect(cloud.pauses, 1);
    expect(cloud.resumes, 1);
    expect(cloud.stops, 1);
    expect(browser.pauses, 0);
    expect(router.activeEngine, isNull);
  });

  test('failed cloud voice selection does not start playback', () async {
    final browser = RouterTestBrowserDelegate();
    final cloud = RouterTestCloudDelegate()..selectResult = false;
    final router = ReaderNarrationPlaybackRouter(
      browserDelegate: browser,
      cloudDelegate: cloud,
    );

    final started = await router.start(
      requestFor(snapshotFor(voice: cloudVoice)),
    );

    expect(started, isFalse);
    expect(cloud.starts, 0);
    expect(router.activeEngine, isNull);
    expect(
      router.errorMessage,
      'The selected cloud narrator is not currently available.',
    );
  });
}

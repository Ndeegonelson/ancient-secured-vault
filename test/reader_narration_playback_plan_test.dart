import 'package:ancient_secure_docs/services/reader_narration_access_policy.dart';
import 'package:ancient_secure_docs/services/reader_narration_playback_plan.dart';
import 'package:ancient_secure_docs/services/reader_narration_voice.dart';
import 'package:ancient_secure_docs/services/reader_narration_voice_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

const browserEnglish = ReaderNarrationVoice(
  name: 'Microsoft David',
  locale: 'en-US',
);

const browserFrench = ReaderNarrationVoice(
  name: 'Microsoft Hortense',
  locale: 'fr-FR',
);

const cloudEnglish = ReaderNarrationVoice(
  name: 'African English Guide',
  locale: 'en-GH',
  accent: 'African',
  cloudVoiceId: 'demo-provider:african-english',
  provider: ReaderNarrationVoiceProvider.cloudAi,
  providerKey: 'firebase-functions',
);

const staleCloudEnglish = ReaderNarrationVoice(
  name: 'Removed Cloud Guide',
  locale: 'en-GH',
  cloudVoiceId: 'demo-provider:removed',
  provider: ReaderNarrationVoiceProvider.cloudAi,
  providerKey: 'firebase-functions',
);

ReaderNarrationAccessPolicy policy({
  bool isAdmin = false,
  bool hasActiveSubscription = false,
}) {
  return ReaderNarrationAccessPolicy.fromUserAccess(
    isAdmin: isAdmin,
    hasActiveSubscription: hasActiveSubscription,
  );
}

ReaderNarrationVoiceCatalog catalog({
  required ReaderNarrationAccessPolicy accessPolicy,
  String locale = 'en-US',
  List<ReaderNarrationVoice> browserVoices = const [browserEnglish],
  List<ReaderNarrationVoice> cloudVoices = const [],
  String? preferredVoiceId,
}) {
  return const ReaderNarrationVoiceCatalogBuilder().build(
    accessPolicy: accessPolicy,
    locale: locale,
    browserVoices: browserVoices,
    cloudVoices: cloudVoices,
    preferredVoiceId: preferredVoiceId,
  );
}

void main() {
  const planner = ReaderNarrationPlaybackPlanner();

  test('free users route to the assigned browser narrator', () {
    final plan = planner.plan(catalog: catalog(accessPolicy: policy()));

    expect(plan.canStart, isTrue);
    expect(plan.engine, ReaderNarrationPlaybackEngine.browser);
    expect(plan.usesCloud, isFalse);
    expect(plan.voice, browserEnglish);
    expect(plan.message, 'Assigned browser narrator selected.');
  });

  test('premium users route selected cloud voices to cloud narration', () {
    final plan = planner.plan(
      catalog: catalog(
        accessPolicy: policy(hasActiveSubscription: true),
        cloudVoices: const [cloudEnglish],
      ),
      selectedVoice: cloudEnglish,
    );

    expect(plan.canStart, isTrue);
    expect(plan.engine, ReaderNarrationPlaybackEngine.cloud);
    expect(plan.usesCloud, isTrue);
    expect(plan.voice, cloudEnglish);
    expect(plan.message, 'Secure cloud narration selected.');
  });

  test('premium users route selected browser voices to browser narration', () {
    final plan = planner.plan(
      catalog: catalog(
        accessPolicy: policy(hasActiveSubscription: true),
        cloudVoices: const [cloudEnglish],
      ),
      selectedVoice: browserEnglish,
    );

    expect(plan.canStart, isTrue);
    expect(plan.engine, ReaderNarrationPlaybackEngine.browser);
    expect(plan.voice, browserEnglish);
    expect(plan.message, 'Browser narration selected.');
  });

  test('stale cloud selection falls back to assigned browser narrator', () {
    final plan = planner.plan(
      catalog: catalog(
        accessPolicy: policy(hasActiveSubscription: true),
        cloudVoices: const [cloudEnglish],
      ),
      selectedVoice: staleCloudEnglish,
    );

    expect(plan.canStart, isTrue);
    expect(plan.engine, ReaderNarrationPlaybackEngine.browser);
    expect(plan.voice, browserEnglish);
    expect(plan.message, 'Browser narration selected.');
  });

  test('preferred cloud voice becomes the route when still available', () {
    final plan = planner.plan(
      catalog: catalog(
        accessPolicy: policy(hasActiveSubscription: true),
        cloudVoices: const [cloudEnglish],
        preferredVoiceId: cloudEnglish.id,
      ),
    );

    expect(plan.canStart, isTrue);
    expect(plan.engine, ReaderNarrationPlaybackEngine.cloud);
    expect(plan.voice, cloudEnglish);
  });

  test('missing compatible voices produce a clear unavailable plan', () {
    final plan = planner.plan(
      catalog: catalog(
        accessPolicy: policy(hasActiveSubscription: true),
        locale: 'fr-FR',
        browserVoices: const [browserEnglish],
        cloudVoices: const [cloudEnglish],
      ),
    );

    expect(plan.canStart, isFalse);
    expect(plan.voice, isNull);
    expect(
      plan.message,
      'No compatible narrator is available for this language.',
    );
  });

  test(
    'language-compatible browser fallback is used when cloud is unavailable',
    () {
      final plan = planner.plan(
        catalog: catalog(
          accessPolicy: policy(hasActiveSubscription: true),
          locale: 'fr-FR',
          browserVoices: const [browserEnglish, browserFrench],
          cloudVoices: const [],
        ),
        selectedVoice: staleCloudEnglish,
      );

      expect(plan.canStart, isTrue);
      expect(plan.engine, ReaderNarrationPlaybackEngine.browser);
      expect(plan.voice, browserFrench);
    },
  );
}

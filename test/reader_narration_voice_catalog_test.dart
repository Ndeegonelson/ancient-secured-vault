import 'package:ancient_secure_docs/services/reader_cloud_narration_provider.dart';
import 'package:ancient_secure_docs/services/reader_narration_access_policy.dart';
import 'package:ancient_secure_docs/services/reader_narration_voice.dart';
import 'package:ancient_secure_docs/services/reader_narration_voice_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

const browserEnglishDavid = ReaderNarrationVoice(
  name: 'Microsoft David',
  locale: 'en-US',
);

const browserEnglishZira = ReaderNarrationVoice(
  name: 'Microsoft Zira',
  locale: 'en-US',
);

const browserFrench = ReaderNarrationVoice(
  name: 'Microsoft Hortense',
  locale: 'fr-FR',
);

const cloudAfricanEnglish = ReaderNarrationVoice(
  name: 'African English Guide',
  locale: 'en-GH',
  gender: 'Female',
  accent: 'African',
  style: 'Educational',
  cloudVoiceId: 'demo-provider:african-english',
  provider: ReaderNarrationVoiceProvider.cloudAi,
  providerKey: 'firebase-functions',
);

const cloudFrench = ReaderNarrationVoice(
  name: 'French Study Guide',
  locale: 'fr-FR',
  gender: 'Male',
  accent: 'Francophone African',
  cloudVoiceId: 'demo-provider:african-french',
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

void main() {
  const builder = ReaderNarrationVoiceCatalogBuilder();

  test('free users receive one assigned browser voice only', () {
    final catalog = builder.build(
      accessPolicy: policy(),
      locale: 'en-US',
      browserVoices: const [browserEnglishDavid, browserEnglishZira],
      cloudVoices: const [cloudAfricanEnglish],
    );

    expect(catalog.canChooseVoice, isFalse);
    expect(catalog.assignedVoice, browserEnglishDavid);
    expect(catalog.defaultVoice, browserEnglishDavid);
    expect(catalog.selectableVoices, [browserEnglishDavid]);
    expect(catalog.cloudVoices, isEmpty);
    expect(
      catalog.cloudAvailabilityMessage,
      'Premium narration is required for cloud and customized voices.',
    );
  });

  test('premium users can choose browser and approved cloud voices', () {
    final catalog = builder.build(
      accessPolicy: policy(hasActiveSubscription: true),
      locale: 'en-US',
      browserVoices: const [browserEnglishDavid, browserEnglishZira],
      cloudVoices: const [cloudAfricanEnglish, cloudFrench],
      preferredVoiceId: cloudAfricanEnglish.id,
    );

    expect(catalog.canChooseVoice, isTrue);
    expect(catalog.assignedVoice, browserEnglishDavid);
    expect(catalog.defaultVoice, cloudAfricanEnglish);
    expect(catalog.browserVoices, [browserEnglishDavid, browserEnglishZira]);
    expect(catalog.cloudVoices, [cloudAfricanEnglish]);
    expect(catalog.selectableVoices, [
      browserEnglishDavid,
      browserEnglishZira,
      cloudAfricanEnglish,
    ]);
    expect(
      catalog.cloudAvailabilityMessage,
      '1 secure cloud narrator available.',
    );
  });

  test('admin users can see compatible custom cloud voices by language', () {
    final catalog = builder.build(
      accessPolicy: policy(isAdmin: true),
      locale: 'fr-CA',
      browserVoices: const [browserEnglishDavid, browserFrench],
      cloudVoices: const [cloudAfricanEnglish, cloudFrench],
    );

    expect(catalog.canChooseVoice, isTrue);
    expect(catalog.assignedVoice, browserFrench);
    expect(catalog.cloudVoices, [cloudFrench]);
    expect(catalog.selectableVoices, [browserFrench, cloudFrench]);
  });

  test('premium catalog surfaces cloud readiness message when unavailable', () {
    final catalog = builder.build(
      accessPolicy: policy(hasActiveSubscription: true),
      locale: 'en-US',
      browserVoices: const [browserEnglishDavid],
      providerStatuses: const {
        'firebase-functions': ReaderCloudNarrationProviderStatus(
          state: ReaderCloudNarrationProviderState.temporarilyUnavailable,
          message: 'Secure cloud narration is waiting for App Check setup.',
        ),
      },
    );

    expect(catalog.cloudVoices, isEmpty);
    expect(
      catalog.cloudAvailabilityMessage,
      'Secure cloud narration is waiting for App Check setup.',
    );
  });

  test('deduplicates selectable voices by stable voice id', () {
    final catalog = builder.build(
      accessPolicy: policy(hasActiveSubscription: true),
      locale: 'en-US',
      browserVoices: const [browserEnglishDavid, browserEnglishDavid],
      cloudVoices: const [cloudAfricanEnglish, cloudAfricanEnglish],
    );

    expect(catalog.selectableVoices, [
      browserEnglishDavid,
      cloudAfricanEnglish,
    ]);
  });
}

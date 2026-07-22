import 'package:ancient_secure_docs/services/reader_narration_access_policy.dart';
import 'package:ancient_secure_docs/services/reader_narration_voice.dart';
import 'package:ancient_secure_docs/services/reader_narration_voice_catalog.dart';
import 'package:ancient_secure_docs/services/reader_narration_voice_catalog_presenter.dart';
import 'package:flutter_test/flutter_test.dart';

const browserDavid = ReaderNarrationVoice(
  name: 'Microsoft David',
  locale: 'en-US',
);

const browserZira = ReaderNarrationVoice(
  name: 'Microsoft Zira',
  locale: 'en-US',
  gender: 'Female',
);

const cloudAfricanGuide = ReaderNarrationVoice(
  name: 'African English Guide',
  locale: 'en-GH',
  accent: 'African',
  cloudVoiceId: 'provider:african-english',
  provider: ReaderNarrationVoiceProvider.cloudAi,
  providerKey: 'future-provider',
);

ReaderNarrationAccessPolicy policy({bool premium = true}) {
  return ReaderNarrationAccessPolicy.fromUserAccess(
    isAdmin: false,
    hasActiveSubscription: premium,
  );
}

ReaderNarrationVoiceCatalog catalog({
  required ReaderNarrationAccessPolicy accessPolicy,
  List<ReaderNarrationVoice> browserVoices = const [browserDavid],
  List<ReaderNarrationVoice> cloudVoices = const [],
  String? preferredVoiceId,
  bool cloudNarrationEnabled = true,
}) {
  return const ReaderNarrationVoiceCatalogBuilder().build(
    accessPolicy: accessPolicy,
    locale: 'en-US',
    browserVoices: browserVoices,
    cloudVoices: cloudVoices,
    preferredVoiceId: preferredVoiceId,
    cloudNarrationEnabled: cloudNarrationEnabled,
  );
}

void main() {
  const presenter = ReaderNarrationVoiceCatalogPresenter();

  test('presents free users with one assigned narrator', () {
    final viewModel = presenter.present(
      catalog: catalog(accessPolicy: policy(premium: false)),
      activeVoice: browserDavid,
      activeLocale: 'en-US',
    );

    expect(
      viewModel.assignedNarratorLabel,
      'Assigned narrator: Microsoft David | en-US',
    );
    expect(viewModel.assignedNarratorAvailable, isTrue);
    expect(
      viewModel.availabilitySummary,
      '1 synced browser voice | natural cloud voices locked',
    );
    expect(viewModel.selectableVoices, [browserDavid]);
    expect(viewModel.canChooseVoice, isFalse);
    expect(viewModel.shouldShowVoiceSelector, isFalse);
    expect(
      viewModel.helperMessage,
      'The narrator is assigned automatically on the free plan.',
    );
  });

  test('presents premium browser choices for selectable narration', () {
    final viewModel = presenter.present(
      catalog: catalog(
        accessPolicy: policy(),
        browserVoices: const [browserDavid, browserZira],
        preferredVoiceId: browserZira.id,
      ),
      activeVoice: browserZira,
      activeLocale: 'en-US',
    );

    expect(
      viewModel.assignedNarratorLabel,
      'Selected narrator: Microsoft Zira | en-US | Female | Read-along',
    );
    expect(
      viewModel.availabilitySummary,
      '2 synced browser voices | no natural cloud voices | '
      'Cloud narrators have not been checked yet.',
    );
    expect(viewModel.selectedVoice, browserZira);
    expect(viewModel.selectableVoices, [browserDavid, browserZira]);
    expect(viewModel.shouldShowVoiceSelector, isTrue);
    expect(
      viewModel.helperMessage,
      'Browser narration is active. Cloud voices are unavailable right now.',
    );
  });

  test('presents cloud voices alongside browser voices for premium users', () {
    final viewModel = presenter.present(
      catalog: catalog(
        accessPolicy: policy(),
        browserVoices: const [browserDavid],
        cloudVoices: const [cloudAfricanGuide],
        preferredVoiceId: cloudAfricanGuide.id,
      ),
      activeVoice: cloudAfricanGuide,
    );

    expect(
      viewModel.assignedNarratorLabel,
      'Selected narrator: African English Guide | en-GH | African | Cloud',
    );
    expect(
      viewModel.availabilitySummary,
      '1 synced browser voice | 1 natural cloud voice',
    );
    expect(viewModel.selectedVoice, cloudAfricanGuide);
    expect(viewModel.selectableVoices, [browserDavid, cloudAfricanGuide]);
    expect(viewModel.shouldShowVoiceSelector, isTrue);
    expect(
      viewModel.helperMessage,
      'Browser voices are best for word-by-word read-along. '
      'Cloud voices provide premium natural narration.',
    );
  });

  test('presents native device narration when cloud audio is disabled', () {
    final viewModel = presenter.present(
      catalog: catalog(
        accessPolicy: policy(),
        browserVoices: const [browserDavid, browserZira],
        cloudVoices: const [cloudAfricanGuide],
        cloudNarrationEnabled: false,
      ),
      activeVoice: browserDavid,
      activeLocale: 'en-US',
    );

    expect(
      viewModel.availabilitySummary,
      '2 synced device voices | natural cloud voices web-only | '
      'Cloud narration audio is available on web only right now.',
    );
    expect(viewModel.selectableVoices, [browserDavid, browserZira]);
    expect(
      viewModel.helperMessage,
      'Device narration is active. Cloud voices are unavailable on this platform.',
    );
  });

  test('uses active locale when no narrator voice is available', () {
    final viewModel = presenter.present(
      catalog: catalog(accessPolicy: policy(), browserVoices: const []),
      activeLocale: 'fr-FR',
    );

    expect(viewModel.assignedNarratorLabel, 'Selected narrator: fr-FR');
    expect(viewModel.assignedNarratorAvailable, isTrue);
    expect(viewModel.selectableVoices, isEmpty);
    expect(
      viewModel.helperMessage,
      'No compatible narrator was detected for this language.',
    );
  });
}

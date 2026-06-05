import 'package:ancient_secure_docs/services/reader_cloud_narration_session_coordinator.dart';
import 'package:ancient_secure_docs/services/reader_narration_access_policy.dart';
import 'package:ancient_secure_docs/services/reader_narration_playback_plan.dart';
import 'package:ancient_secure_docs/services/reader_narration_playback_snapshot.dart';
import 'package:ancient_secure_docs/services/reader_narration_voice.dart';
import 'package:ancient_secure_docs/services/reader_narration_voice_catalog.dart';
import 'package:ancient_secure_docs/services/reader_tts_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

class SnapshotTestFlutterTts extends FlutterTts {
  SnapshotTestFlutterTts({
    this.availableLanguages = const ['en-US', 'fr-FR'],
    this.availableVoices = const [
      {'name': 'Microsoft David', 'locale': 'en-US'},
      {'name': 'Microsoft Zira', 'locale': 'en-US'},
      {'name': 'Microsoft Hortense', 'locale': 'fr-FR'},
    ],
  });

  final List<String> availableLanguages;
  final List<Map<String, String>> availableVoices;

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async => 1;

  @override
  Future<dynamic> setVolume(double volume) async => 1;

  @override
  Future<dynamic> setPitch(double pitch) async => 1;

  @override
  Future<dynamic> get getLanguages async => availableLanguages;

  @override
  Future<dynamic> get getVoices async => availableVoices;

  @override
  Future<dynamic> setLanguage(String language) async => 1;

  @override
  Future<dynamic> setVoice(Map<String, String> voice) async => 1;

  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;

  @override
  void setStartHandler(VoidCallback callback) {}

  @override
  void setPauseHandler(VoidCallback callback) {}

  @override
  void setContinueHandler(VoidCallback callback) {}

  @override
  void setCompletionHandler(VoidCallback callback) {}

  @override
  void setCancelHandler(VoidCallback callback) {}

  @override
  void setProgressHandler(ProgressHandler callback) {}

  @override
  void setErrorHandler(ErrorHandler callback) {}
}

const browserEnglishDavid = ReaderNarrationVoice(
  name: 'Microsoft David',
  locale: 'en-US',
);

const browserEnglishZira = ReaderNarrationVoice(
  name: 'Microsoft Zira',
  locale: 'en-US',
);

const cloudAfricanEnglish = ReaderNarrationVoice(
  name: 'African English Guide',
  locale: 'en-GH',
  accent: 'African',
  cloudVoiceId: 'demo-provider:african-english',
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

Future<ReaderTtsService> initializedTtsService({
  ReaderNarrationLanguage language = ReaderNarrationLanguage.english,
  String? preferredVoiceId,
}) async {
  final service = ReaderTtsService(flutterTts: SnapshotTestFlutterTts());
  service.restorePreferences(
    language: language,
    rate: ReaderTtsService.defaultRate,
    voiceId: preferredVoiceId,
  );
  await service.initialize();
  return service;
}

void main() {
  const builder = ReaderNarrationPlaybackSnapshotBuilder();

  test('free snapshot routes to the assigned browser narrator', () async {
    final ttsService = await initializedTtsService();

    final snapshot = builder.build(
      accessPolicy: policy(),
      ttsService: ttsService,
    );

    expect(snapshot.canStart, isTrue);
    expect(snapshot.usesCloud, isFalse);
    expect(snapshot.selectedVoice, browserEnglishDavid);
    expect(snapshot.selectableVoices, [browserEnglishDavid]);
    expect(snapshot.plan.engine, ReaderNarrationPlaybackEngine.browser);
    expect(snapshot.statusMessage, 'Assigned browser narrator selected.');

    ttsService.dispose();
  });

  test('premium snapshot keeps saved browser preference as default', () async {
    final ttsService = await initializedTtsService(
      preferredVoiceId: browserEnglishZira.id,
    );

    final snapshot = builder.build(
      accessPolicy: policy(hasActiveSubscription: true),
      ttsService: ttsService,
    );

    expect(snapshot.canStart, isTrue);
    expect(snapshot.usesCloud, isFalse);
    expect(snapshot.selectedVoice, browserEnglishZira);
    expect(snapshot.selectableVoices, [
      browserEnglishDavid,
      browserEnglishZira,
    ]);
    expect(
      snapshot.statusMessage,
      'Cloud narrators have not been checked yet.',
    );

    ttsService.dispose();
  });

  test('premium snapshot can route an approved selected cloud voice', () async {
    final ttsService = await initializedTtsService();

    final snapshot =
        const ReaderNarrationPlaybackSnapshotBuilder(
          catalogBuilder: SnapshotCatalogBuilder(
            cloudVoices: [cloudAfricanEnglish],
          ),
        ).build(
          accessPolicy: policy(hasActiveSubscription: true),
          ttsService: ttsService,
          selectedVoice: cloudAfricanEnglish,
        );

    expect(snapshot.canStart, isTrue);
    expect(snapshot.usesCloud, isTrue);
    expect(snapshot.selectedVoice, cloudAfricanEnglish);
    expect(snapshot.plan.engine, ReaderNarrationPlaybackEngine.cloud);
    expect(snapshot.statusMessage, 'Secure cloud narration selected.');

    ttsService.dispose();
  });

  test(
    'snapshot reports no compatible narrator for missing language',
    () async {
      final ttsService = await initializedTtsService(
        language: ReaderNarrationLanguage.french,
      );

      final snapshot =
          const ReaderNarrationPlaybackSnapshotBuilder(
            catalogBuilder: SnapshotCatalogBuilder(browserVoices: []),
          ).build(
            accessPolicy: policy(hasActiveSubscription: true),
            ttsService: ttsService,
          );

      expect(snapshot.canStart, isFalse);
      expect(snapshot.selectedVoice, isNull);
      expect(
        snapshot.statusMessage,
        'No compatible narrator is available for this language.',
      );

      ttsService.dispose();
    },
  );
}

class SnapshotCatalogBuilder extends ReaderNarrationVoiceCatalogBuilder {
  const SnapshotCatalogBuilder({
    this.browserVoices,
    this.cloudVoices = const [],
  });

  final List<ReaderNarrationVoice>? browserVoices;
  final List<ReaderNarrationVoice> cloudVoices;

  @override
  ReaderNarrationVoiceCatalog buildFromServices({
    required ReaderNarrationAccessPolicy accessPolicy,
    required ReaderTtsService ttsService,
    ReaderCloudNarrationSessionCoordinator? cloudSession,
  }) {
    return build(
      accessPolicy: accessPolicy,
      locale: ttsService.effectiveLanguage.locale,
      browserVoices: browserVoices ?? ttsService.availableBrowserVoices,
      cloudVoices: cloudVoices,
      preferredVoiceId: ttsService.preferredVoiceId,
    );
  }
}

import 'reader_cloud_narration_session_coordinator.dart';
import 'reader_narration_access_policy.dart';
import 'reader_narration_playback_plan.dart';
import 'reader_narration_voice.dart';
import 'reader_narration_voice_catalog.dart';
import 'reader_tts_service.dart';

class ReaderNarrationPlaybackSnapshot {
  const ReaderNarrationPlaybackSnapshot({
    required this.catalog,
    required this.plan,
  });

  final ReaderNarrationVoiceCatalog catalog;
  final ReaderNarrationPlaybackPlan plan;

  bool get canStart => plan.canStart;
  bool get usesCloud => plan.usesCloud;
  ReaderNarrationVoice? get selectedVoice => plan.voice;
  List<ReaderNarrationVoice> get selectableVoices => catalog.selectableVoices;

  String get statusMessage {
    if (!plan.canStart) return plan.message;
    if (plan.usesCloud) return plan.message;
    if (catalog.accessPolicy.canUseCloudNarration && !catalog.hasCloudVoices) {
      return catalog.cloudAvailabilityMessage;
    }

    return plan.message;
  }
}

class ReaderNarrationPlaybackSnapshotBuilder {
  const ReaderNarrationPlaybackSnapshotBuilder({
    this.catalogBuilder = const ReaderNarrationVoiceCatalogBuilder(),
    this.playbackPlanner = const ReaderNarrationPlaybackPlanner(),
  });

  final ReaderNarrationVoiceCatalogBuilder catalogBuilder;
  final ReaderNarrationPlaybackPlanner playbackPlanner;

  ReaderNarrationPlaybackSnapshot build({
    required ReaderNarrationAccessPolicy accessPolicy,
    required ReaderTtsService ttsService,
    ReaderCloudNarrationSessionCoordinator? cloudSession,
    ReaderNarrationVoice? selectedVoice,
  }) {
    final catalog = catalogBuilder.buildFromServices(
      accessPolicy: accessPolicy,
      ttsService: ttsService,
      cloudSession: cloudSession,
    );
    final plan = playbackPlanner.plan(
      catalog: catalog,
      selectedVoice: selectedVoice ?? ttsService.selectedVoice,
    );

    return ReaderNarrationPlaybackSnapshot(catalog: catalog, plan: plan);
  }
}

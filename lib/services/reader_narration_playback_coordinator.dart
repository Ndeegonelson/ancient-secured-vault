import 'reader_cloud_narration_session_coordinator.dart';
import 'reader_narration_access_policy.dart';
import 'reader_narration_playback_plan.dart';
import 'reader_narration_playback_router.dart';
import 'reader_narration_playback_router_factory.dart';
import 'reader_narration_playback_snapshot.dart';
import 'reader_narration_voice.dart';
import 'reader_tts_service.dart';

typedef ReaderNarrationAccessPolicyProvider =
    ReaderNarrationAccessPolicy Function();

class ReaderNarrationPlaybackCoordinator {
  ReaderNarrationPlaybackCoordinator({
    required this.ttsService,
    required this.accessPolicyProvider,
    this.cloudSession,
    this.snapshotBuilder = const ReaderNarrationPlaybackSnapshotBuilder(),
    ReaderNarrationPlaybackRouterFactory routerFactory =
        const ReaderNarrationPlaybackRouterFactory(),
    ReaderNarrationPlaybackRouter? router,
  }) : router =
           router ??
           routerFactory.create(
             ttsService: ttsService,
             cloudSession: cloudSession,
           );

  final ReaderTtsService ttsService;
  final ReaderCloudNarrationSessionCoordinator? cloudSession;
  final ReaderNarrationAccessPolicyProvider accessPolicyProvider;
  final ReaderNarrationPlaybackSnapshotBuilder snapshotBuilder;
  final ReaderNarrationPlaybackRouter router;

  ReaderNarrationPlaybackStatus get status => router.status;
  ReaderNarrationRouterState get state => router.state;
  bool get isPlaying => router.isPlaying;
  bool get isPaused => router.isPaused;
  bool get isUsingCloud => router.isUsingCloud;
  ReaderNarrationVoice? get selectedVoice =>
      cloudSession?.selectedVoice ?? ttsService.selectedVoice;

  ReaderNarrationPlaybackSnapshot snapshot({
    ReaderNarrationVoice? selectedVoice,
  }) {
    return snapshotBuilder.build(
      accessPolicy: accessPolicyProvider(),
      ttsService: ttsService,
      cloudSession: cloudSession,
      selectedVoice: selectedVoice,
    );
  }

  Future<bool> start({
    required String text,
    required int pageNumber,
    required double rate,
    int startCharacter = 0,
    bool continueAcrossPages = true,
    ReaderNarrationVoice? selectedVoice,
  }) {
    return router.start(
      ReaderNarrationPlaybackStartRequest(
        snapshot: snapshot(selectedVoice: selectedVoice),
        text: text,
        pageNumber: pageNumber,
        rate: rate,
        startCharacter: startCharacter,
        continueAcrossPages: continueAcrossPages,
      ),
    );
  }

  Future<bool> selectVoice(ReaderNarrationVoice voice) async {
    final currentSnapshot = snapshot(selectedVoice: voice);
    final isSelectable = currentSnapshot.selectableVoices.any(
      (item) => item.id == voice.id,
    );
    final plannedVoice = currentSnapshot.selectedVoice;

    if (!isSelectable || !currentSnapshot.canStart || plannedVoice == null) {
      return false;
    }

    if (currentSnapshot.plan.engine == ReaderNarrationPlaybackEngine.cloud) {
      final cloudDelegate = router.cloudDelegate;
      if (cloudDelegate == null) return false;

      await router.browserDelegate.stopBrowserNarration();
      return cloudDelegate.selectCloudVoice(plannedVoice);
    }

    await router.cloudDelegate?.stopCloudNarration();
    await router.browserDelegate.setVoice(plannedVoice);
    return true;
  }

  Future<void> pause() => router.pause();

  Future<bool> resume() => router.resume();

  Future<void> stop() => router.stop();

  Future<void> stopAll() => router.stopAll();
}

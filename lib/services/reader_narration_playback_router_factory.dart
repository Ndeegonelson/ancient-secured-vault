import 'reader_cloud_narration_session_coordinator.dart';
import 'reader_narration_playback_delegates.dart';
import 'reader_narration_playback_router.dart';
import 'reader_tts_service.dart';

class ReaderNarrationPlaybackRouterFactory {
  const ReaderNarrationPlaybackRouterFactory();

  ReaderNarrationPlaybackRouter create({
    required ReaderTtsService ttsService,
    ReaderCloudNarrationSessionCoordinator? cloudSession,
  }) {
    return ReaderNarrationPlaybackRouter(
      browserDelegate: ReaderTtsBrowserNarrationDelegate(ttsService),
      cloudDelegate: cloudSession == null
          ? null
          : ReaderCloudSessionNarrationDelegate(cloudSession),
    );
  }
}

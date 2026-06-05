import 'reader_cloud_narration_session_coordinator.dart';
import 'reader_narration_playback_router.dart';
import 'reader_narration_voice.dart';
import 'reader_tts_service.dart';

class ReaderTtsBrowserNarrationDelegate
    implements ReaderBrowserNarrationDelegate {
  const ReaderTtsBrowserNarrationDelegate(this.service);

  final ReaderTtsService service;

  @override
  Future<void> setVoice(ReaderNarrationVoice voice) {
    return service.setVoice(voice);
  }

  @override
  Future<bool> startBrowserNarration({
    required String text,
    required int pageNumber,
    required int startCharacter,
    required bool continueAcrossPages,
  }) {
    return service.speakPage(
      text: text,
      pageNumber: pageNumber,
      startCharacter: startCharacter,
      continueAcrossPages: continueAcrossPages,
    );
  }

  @override
  Future<void> pauseBrowserNarration() {
    return service.pause();
  }

  @override
  Future<bool> resumeBrowserNarration() {
    return service.resume();
  }

  @override
  Future<void> stopBrowserNarration() {
    return service.stop();
  }
}

class ReaderCloudSessionNarrationDelegate
    implements ReaderCloudNarrationDelegate {
  const ReaderCloudSessionNarrationDelegate(this.session);

  final ReaderCloudNarrationSessionCoordinator session;

  @override
  Future<bool> selectCloudVoice(ReaderNarrationVoice voice) {
    return session.selectVoice(voice);
  }

  @override
  Future<bool> startCloudNarration({
    required String text,
    required double rate,
    required int startCharacter,
  }) {
    return session.start(
      text: text,
      rate: rate,
      startCharacter: startCharacter,
    );
  }

  @override
  Future<void> pauseCloudNarration() {
    return session.pause();
  }

  @override
  Future<void> resumeCloudNarration() {
    return session.resume();
  }

  @override
  Future<void> stopCloudNarration() {
    return session.stop();
  }
}

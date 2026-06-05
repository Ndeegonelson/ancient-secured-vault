import 'reader_narration_playback_plan.dart';
import 'reader_narration_playback_snapshot.dart';
import 'reader_narration_voice.dart';

abstract interface class ReaderBrowserNarrationDelegate {
  Future<void> setVoice(ReaderNarrationVoice voice);

  Future<bool> startBrowserNarration({
    required String text,
    required int pageNumber,
    required int startCharacter,
    required bool continueAcrossPages,
  });

  Future<void> pauseBrowserNarration();

  Future<bool> resumeBrowserNarration();

  Future<void> stopBrowserNarration();
}

abstract interface class ReaderCloudNarrationDelegate {
  Future<bool> selectCloudVoice(ReaderNarrationVoice voice);

  Future<bool> startCloudNarration({
    required String text,
    required double rate,
    required int startCharacter,
  });

  Future<void> pauseCloudNarration();

  Future<void> resumeCloudNarration();

  Future<void> stopCloudNarration();
}

class ReaderNarrationPlaybackStartRequest {
  const ReaderNarrationPlaybackStartRequest({
    required this.snapshot,
    required this.text,
    required this.pageNumber,
    required this.rate,
    this.startCharacter = 0,
    this.continueAcrossPages = true,
  });

  final ReaderNarrationPlaybackSnapshot snapshot;
  final String text;
  final int pageNumber;
  final double rate;
  final int startCharacter;
  final bool continueAcrossPages;
}

class ReaderNarrationPlaybackRouter {
  ReaderNarrationPlaybackRouter({
    required this.browserDelegate,
    this.cloudDelegate,
  });

  final ReaderBrowserNarrationDelegate browserDelegate;
  final ReaderCloudNarrationDelegate? cloudDelegate;
  ReaderNarrationPlaybackEngine? _activeEngine;
  String? _errorMessage;

  ReaderNarrationPlaybackEngine? get activeEngine => _activeEngine;
  String? get errorMessage => _errorMessage;
  bool get isUsingCloud => _activeEngine == ReaderNarrationPlaybackEngine.cloud;

  Future<bool> start(ReaderNarrationPlaybackStartRequest request) async {
    _errorMessage = null;
    final plan = request.snapshot.plan;
    if (!plan.canStart) {
      _errorMessage = plan.message;
      return false;
    }

    final voice = plan.voice;
    if (voice == null) {
      _errorMessage = 'No compatible narrator is available for this language.';
      return false;
    }

    if (plan.engine == ReaderNarrationPlaybackEngine.cloud) {
      final cloudDelegate = this.cloudDelegate;
      if (cloudDelegate == null) {
        _errorMessage = 'Secure cloud narration is not connected yet.';
        return false;
      }

      await browserDelegate.stopBrowserNarration();
      final selected = await cloudDelegate.selectCloudVoice(voice);
      if (!selected) {
        _errorMessage =
            'The selected cloud narrator is not currently available.';
        return false;
      }

      final started = await cloudDelegate.startCloudNarration(
        text: request.text,
        rate: request.rate,
        startCharacter: request.startCharacter,
      );
      _activeEngine = started ? ReaderNarrationPlaybackEngine.cloud : null;
      if (!started) {
        _errorMessage = 'Secure cloud narration could not start.';
      }
      return started;
    }

    await cloudDelegate?.stopCloudNarration();
    await browserDelegate.setVoice(voice);
    final started = await browserDelegate.startBrowserNarration(
      text: request.text,
      pageNumber: request.pageNumber,
      startCharacter: request.startCharacter,
      continueAcrossPages: request.continueAcrossPages,
    );
    _activeEngine = started ? ReaderNarrationPlaybackEngine.browser : null;
    if (!started) {
      _errorMessage = 'Browser narration could not start.';
    }
    return started;
  }

  Future<void> pause() async {
    switch (_activeEngine) {
      case ReaderNarrationPlaybackEngine.cloud:
        await cloudDelegate?.pauseCloudNarration();
        return;
      case ReaderNarrationPlaybackEngine.browser:
        await browserDelegate.pauseBrowserNarration();
        return;
      case null:
        return;
    }
  }

  Future<bool> resume() async {
    switch (_activeEngine) {
      case ReaderNarrationPlaybackEngine.cloud:
        await cloudDelegate?.resumeCloudNarration();
        return cloudDelegate != null;
      case ReaderNarrationPlaybackEngine.browser:
        return browserDelegate.resumeBrowserNarration();
      case null:
        return false;
    }
  }

  Future<void> stop() async {
    final previousEngine = _activeEngine;
    _activeEngine = null;
    switch (previousEngine) {
      case ReaderNarrationPlaybackEngine.cloud:
        await cloudDelegate?.stopCloudNarration();
        return;
      case ReaderNarrationPlaybackEngine.browser:
        await browserDelegate.stopBrowserNarration();
        return;
      case null:
        await cloudDelegate?.stopCloudNarration();
        await browserDelegate.stopBrowserNarration();
        return;
    }
  }

  Future<void> stopAll() async {
    _activeEngine = null;
    await cloudDelegate?.stopCloudNarration();
    await browserDelegate.stopBrowserNarration();
  }
}

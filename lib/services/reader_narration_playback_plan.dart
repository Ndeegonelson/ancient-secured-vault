import 'reader_narration_voice.dart';
import 'reader_narration_voice_catalog.dart';

enum ReaderNarrationPlaybackEngine { browser, cloud }

class ReaderNarrationPlaybackPlan {
  const ReaderNarrationPlaybackPlan._({
    required this.engine,
    required this.voice,
    required this.canStart,
    required this.message,
  });

  factory ReaderNarrationPlaybackPlan.ready({
    required ReaderNarrationPlaybackEngine engine,
    required ReaderNarrationVoice voice,
    required String message,
  }) {
    return ReaderNarrationPlaybackPlan._(
      engine: engine,
      voice: voice,
      canStart: true,
      message: message,
    );
  }

  factory ReaderNarrationPlaybackPlan.unavailable(String message) {
    return ReaderNarrationPlaybackPlan._(
      engine: ReaderNarrationPlaybackEngine.browser,
      voice: null,
      canStart: false,
      message: message,
    );
  }

  final ReaderNarrationPlaybackEngine engine;
  final ReaderNarrationVoice? voice;
  final bool canStart;
  final String message;

  bool get usesCloud => engine == ReaderNarrationPlaybackEngine.cloud;
}

class ReaderNarrationPlaybackPlanner {
  const ReaderNarrationPlaybackPlanner();

  ReaderNarrationPlaybackPlan plan({
    required ReaderNarrationVoiceCatalog catalog,
    ReaderNarrationVoice? selectedVoice,
  }) {
    final chosenVoice =
        _selectAllowedVoice(catalog, selectedVoice) ?? catalog.defaultVoice;
    if (chosenVoice == null) {
      return ReaderNarrationPlaybackPlan.unavailable(
        'No compatible narrator is available for this language.',
      );
    }

    if (chosenVoice.provider == ReaderNarrationVoiceProvider.cloudAi) {
      if (!catalog.accessPolicy.canUseCloudNarration) {
        return _browserFallbackPlan(
          catalog,
          'Premium narration is required for cloud and customized voices.',
        );
      }

      if (!_containsVoice(catalog.cloudVoices, chosenVoice)) {
        return _browserFallbackPlan(
          catalog,
          'The selected cloud narrator is no longer available.',
        );
      }

      return ReaderNarrationPlaybackPlan.ready(
        engine: ReaderNarrationPlaybackEngine.cloud,
        voice: chosenVoice,
        message: 'Secure cloud narration selected.',
      );
    }

    return ReaderNarrationPlaybackPlan.ready(
      engine: ReaderNarrationPlaybackEngine.browser,
      voice: chosenVoice,
      message: catalog.canChooseVoice
          ? 'Browser narration selected.'
          : 'Assigned browser narrator selected.',
    );
  }

  ReaderNarrationPlaybackPlan _browserFallbackPlan(
    ReaderNarrationVoiceCatalog catalog,
    String message,
  ) {
    final fallbackVoice = catalog.assignedVoice ?? catalog.defaultVoice;
    if (fallbackVoice == null) {
      return ReaderNarrationPlaybackPlan.unavailable(message);
    }

    return ReaderNarrationPlaybackPlan.ready(
      engine: ReaderNarrationPlaybackEngine.browser,
      voice: fallbackVoice,
      message: message,
    );
  }

  ReaderNarrationVoice? _selectAllowedVoice(
    ReaderNarrationVoiceCatalog catalog,
    ReaderNarrationVoice? selectedVoice,
  ) {
    if (selectedVoice == null) return null;

    for (final voice in catalog.selectableVoices) {
      if (voice.id == selectedVoice.id) return voice;
    }

    return null;
  }

  bool _containsVoice(
    List<ReaderNarrationVoice> voices,
    ReaderNarrationVoice voice,
  ) {
    return voices.any((item) => item.id == voice.id);
  }
}

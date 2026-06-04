import 'reader_cloud_narration_provider.dart';
import 'reader_narration_voice.dart';

class ReaderCloudNarrationCatalog {
  const ReaderCloudNarrationCatalog({
    required this.voices,
    required this.providerStatuses,
  });

  final List<ReaderNarrationVoice> voices;
  final Map<String, ReaderCloudNarrationProviderStatus> providerStatuses;

  bool get hasReadyProvider =>
      providerStatuses.values.any((status) => status.isReady);
}

class ReaderCloudNarrationRegistry {
  const ReaderCloudNarrationRegistry({this.providers = const []});

  final List<ReaderCloudNarrationProvider> providers;

  Future<ReaderCloudNarrationCatalog> loadCatalog() async {
    final voicesById = <String, ReaderNarrationVoice>{};
    final statuses = <String, ReaderCloudNarrationProviderStatus>{};

    for (final provider in providers) {
      try {
        final status = await provider.checkStatus();
        statuses[provider.key] = status;
        if (!status.isReady) continue;

        final voices = await provider.loadVoices();
        for (final voice in voices) {
          final normalizedVoice = voice.copyWith(
            provider: ReaderNarrationVoiceProvider.cloudAi,
            providerKey: provider.key,
          );
          voicesById[normalizedVoice.id] = normalizedVoice;
        }
      } catch (_) {
        statuses[provider.key] = ReaderCloudNarrationProviderStatus(
          state: ReaderCloudNarrationProviderState.temporarilyUnavailable,
          message: '${provider.displayName} is temporarily unavailable.',
        );
      }
    }

    return ReaderCloudNarrationCatalog(
      voices: voicesById.values.toList(growable: false),
      providerStatuses: Map.unmodifiable(statuses),
    );
  }

  ReaderCloudNarrationProvider? providerForVoice(ReaderNarrationVoice voice) {
    if (voice.provider != ReaderNarrationVoiceProvider.cloudAi) return null;

    for (final provider in providers) {
      if (provider.key == voice.providerKey) return provider;
    }

    return null;
  }

  Future<ReaderCloudNarrationAudioSegment> synthesize(
    ReaderCloudNarrationSynthesisRequest request,
  ) async {
    final provider = providerForVoice(request.voice);
    if (provider == null) {
      throw StateError('No cloud narration provider matches this voice.');
    }

    final status = await provider.checkStatus();
    if (!status.isReady) {
      throw StateError(status.message);
    }

    final segment = await provider.synthesize(request);
    if (!segment.isValidFor(request)) {
      throw StateError(
        '${provider.displayName} returned an invalid narration segment.',
      );
    }

    return segment;
  }
}

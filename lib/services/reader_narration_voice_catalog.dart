import 'reader_cloud_narration_provider.dart';
import 'reader_cloud_narration_session_coordinator.dart';
import 'reader_narration_access_policy.dart';
import 'reader_narration_voice.dart';
import 'reader_tts_service.dart';

class ReaderNarrationVoiceCatalog {
  const ReaderNarrationVoiceCatalog({
    required this.accessPolicy,
    required this.locale,
    required this.cloudNarrationEnabled,
    required this.assignedVoice,
    required this.defaultVoice,
    required this.browserVoices,
    required this.cloudVoices,
    required this.selectableVoices,
    required this.providerStatuses,
  });

  final ReaderNarrationAccessPolicy accessPolicy;
  final String locale;
  final bool cloudNarrationEnabled;
  final ReaderNarrationVoice? assignedVoice;
  final ReaderNarrationVoice? defaultVoice;
  final List<ReaderNarrationVoice> browserVoices;
  final List<ReaderNarrationVoice> cloudVoices;
  final List<ReaderNarrationVoice> selectableVoices;
  final Map<String, ReaderCloudNarrationProviderStatus> providerStatuses;

  bool get hasCloudVoices => cloudVoices.isNotEmpty;
  bool get canChooseVoice => accessPolicy.canChooseVoice;

  String get cloudAvailabilityMessage {
    if (!cloudNarrationEnabled) {
      return 'Cloud narration audio is available on web only right now.';
    }

    if (!accessPolicy.canUseCloudNarration) {
      return accessPolicy.cloudUpgradeMessage;
    }

    if (cloudVoices.isNotEmpty) {
      return '${cloudVoices.length} secure cloud narrator'
          '${cloudVoices.length == 1 ? '' : 's'} available.';
    }

    if (providerStatuses.isEmpty) {
      return 'Cloud narrators have not been checked yet.';
    }

    final unavailableStatuses = providerStatuses.values.where(
      (status) => !status.isReady && status.message.trim().isNotEmpty,
    );
    if (unavailableStatuses.isNotEmpty) {
      return unavailableStatuses.first.message;
    }

    return 'No secure cloud narrator is available for this language yet.';
  }
}

class ReaderNarrationVoiceCatalogBuilder {
  const ReaderNarrationVoiceCatalogBuilder();

  ReaderNarrationVoiceCatalog buildFromServices({
    required ReaderNarrationAccessPolicy accessPolicy,
    required ReaderTtsService ttsService,
    ReaderCloudNarrationSessionCoordinator? cloudSession,
    bool cloudNarrationEnabled = true,
  }) {
    return build(
      accessPolicy: accessPolicy,
      locale: ttsService.effectiveLanguage.locale,
      browserVoices: ttsService.availableBrowserVoices,
      cloudVoices: cloudSession?.availableVoices ?? const [],
      providerStatuses: cloudSession?.providerStatuses ?? const {},
      preferredVoiceId: ttsService.preferredVoiceId,
      cloudNarrationEnabled: cloudNarrationEnabled,
    );
  }

  ReaderNarrationVoiceCatalog build({
    required ReaderNarrationAccessPolicy accessPolicy,
    required String locale,
    required List<ReaderNarrationVoice> browserVoices,
    List<ReaderNarrationVoice> cloudVoices = const [],
    Map<String, ReaderCloudNarrationProviderStatus> providerStatuses = const {},
    String? preferredVoiceId,
    bool cloudNarrationEnabled = true,
  }) {
    final normalizedLocale = locale.trim().isEmpty ? 'en-US' : locale.trim();
    final compatibleBrowserVoices = _compatibleVoices(
      browserVoices,
      normalizedLocale,
    );
    final compatibleCloudVoices =
        cloudNarrationEnabled && accessPolicy.canUseCloudNarration
        ? _compatibleVoices(cloudVoices, normalizedLocale)
        : <ReaderNarrationVoice>[];
    final assignedVoice = _firstOrNull(compatibleBrowserVoices);

    final selectableVoices = accessPolicy.canChooseVoice
        ? _dedupeById([...compatibleBrowserVoices, ...compatibleCloudVoices])
        : assignedVoice == null
        ? <ReaderNarrationVoice>[]
        : [assignedVoice];
    final defaultVoice =
        _voiceById(selectableVoices, preferredVoiceId) ??
        assignedVoice ??
        _firstOrNull(selectableVoices);

    return ReaderNarrationVoiceCatalog(
      accessPolicy: accessPolicy,
      locale: normalizedLocale,
      cloudNarrationEnabled: cloudNarrationEnabled,
      assignedVoice: assignedVoice,
      defaultVoice: defaultVoice,
      browserVoices: List.unmodifiable(compatibleBrowserVoices),
      cloudVoices: List.unmodifiable(compatibleCloudVoices),
      selectableVoices: List.unmodifiable(selectableVoices),
      providerStatuses: Map.unmodifiable(providerStatuses),
    );
  }

  List<ReaderNarrationVoice> _compatibleVoices(
    List<ReaderNarrationVoice> voices,
    String locale,
  ) {
    return voices
        .where((voice) => voice.supportsBaseLocale(locale))
        .toList(growable: false);
  }

  List<ReaderNarrationVoice> _dedupeById(List<ReaderNarrationVoice> voices) {
    final voicesById = <String, ReaderNarrationVoice>{};
    for (final voice in voices) {
      voicesById[voice.id] = voice;
    }

    return voicesById.values.toList(growable: false);
  }

  ReaderNarrationVoice? _voiceById(
    List<ReaderNarrationVoice> voices,
    String? voiceId,
  ) {
    if (voiceId == null || voiceId.trim().isEmpty) return null;

    for (final voice in voices) {
      if (voice.id == voiceId) return voice;
    }

    return null;
  }

  ReaderNarrationVoice? _firstOrNull(List<ReaderNarrationVoice> voices) {
    return voices.isEmpty ? null : voices.first;
  }
}

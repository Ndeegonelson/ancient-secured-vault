import 'reader_narration_voice.dart';
import 'reader_narration_voice_catalog.dart';

class ReaderNarrationVoiceCatalogViewModel {
  const ReaderNarrationVoiceCatalogViewModel({
    required this.assignedNarratorLabel,
    required this.assignedNarratorAvailable,
    required this.availabilitySummary,
    required this.selectableVoices,
    required this.selectedVoice,
    required this.canChooseVoice,
    required this.shouldShowVoiceSelector,
    this.helperMessage,
  });

  final String assignedNarratorLabel;
  final bool assignedNarratorAvailable;
  final String availabilitySummary;
  final List<ReaderNarrationVoice> selectableVoices;
  final ReaderNarrationVoice? selectedVoice;
  final bool canChooseVoice;
  final bool shouldShowVoiceSelector;
  final String? helperMessage;
}

class ReaderNarrationVoiceCatalogPresenter {
  const ReaderNarrationVoiceCatalogPresenter();

  ReaderNarrationVoiceCatalogViewModel present({
    required ReaderNarrationVoiceCatalog catalog,
    ReaderNarrationVoice? activeVoice,
    String? activeLocale,
  }) {
    final displayedVoice =
        _voiceFromCatalog(catalog, activeVoice) ??
        catalog.defaultVoice ??
        catalog.assignedVoice;
    final displayedLocale = activeLocale?.trim();
    final assignedNarratorLabel = displayedVoice == null
        ? displayedLocale == null || displayedLocale.isEmpty
              ? 'Assigned narrator: unavailable'
              : 'Assigned narrator: $displayedLocale'
        : 'Assigned narrator: ${displayedVoice.label}';

    final availabilitySummary = _availabilitySummary(catalog);
    final shouldShowVoiceSelector =
        catalog.accessPolicy.canChooseVoice &&
        catalog.selectableVoices.length > 1;

    return ReaderNarrationVoiceCatalogViewModel(
      assignedNarratorLabel: assignedNarratorLabel,
      assignedNarratorAvailable:
          displayedVoice != null ||
          (displayedLocale != null && displayedLocale.isNotEmpty),
      availabilitySummary: availabilitySummary,
      selectableVoices: catalog.selectableVoices,
      selectedVoice: displayedVoice,
      canChooseVoice: catalog.accessPolicy.canChooseVoice,
      shouldShowVoiceSelector: shouldShowVoiceSelector,
      helperMessage: _helperMessage(catalog),
    );
  }

  ReaderNarrationVoice? _voiceFromCatalog(
    ReaderNarrationVoiceCatalog catalog,
    ReaderNarrationVoice? voice,
  ) {
    if (voice == null) return null;

    for (final item in catalog.selectableVoices) {
      if (item.id == voice.id) return item;
    }

    return null;
  }

  String _availabilitySummary(ReaderNarrationVoiceCatalog catalog) {
    final browserSummary = _countLabel(
      catalog.browserVoices.length,
      singular: 'browser voice',
      plural: 'browser voices',
    );
    final cloudSummary = catalog.accessPolicy.canUseCloudNarration
        ? _countLabel(
            catalog.cloudVoices.length,
            singular: 'cloud voice',
            plural: 'cloud voices',
          )
        : 'cloud voices locked';

    if (catalog.accessPolicy.canUseCloudNarration && !catalog.hasCloudVoices) {
      return '$browserSummary | $cloudSummary | '
          '${catalog.cloudAvailabilityMessage}';
    }

    return '$browserSummary | $cloudSummary';
  }

  String _countLabel(
    int count, {
    required String singular,
    required String plural,
  }) {
    if (count == 0) return 'no $plural';

    return '$count ${count == 1 ? singular : plural}';
  }

  String? _helperMessage(ReaderNarrationVoiceCatalog catalog) {
    if (!catalog.accessPolicy.canChooseVoice) {
      return 'The narrator is assigned automatically on the free plan.';
    }

    if (catalog.selectableVoices.isEmpty) {
      return 'No compatible narrator was detected for this language.';
    }

    if (catalog.selectableVoices.length == 1) {
      return catalog.hasCloudVoices
          ? '1 compatible narrator is available.'
          : '1 compatible browser narrator detected. Additional premium '
                'narrators require a cloud voice provider.';
    }

    if (!catalog.hasCloudVoices) {
      return catalog.cloudAvailabilityMessage;
    }

    return null;
  }
}

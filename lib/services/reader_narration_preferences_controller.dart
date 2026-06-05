import 'reader_narration_playback_coordinator.dart';
import 'reader_narration_preferences_repository.dart';
import 'reader_narration_voice.dart';
import 'reader_tts_service.dart';

enum ReaderNarrationPreferencesWriteResult { skipped, saved, failed }

class ReaderNarrationPreferencesContext {
  const ReaderNarrationPreferencesContext({required this.userEmail});

  final String? userEmail;

  bool get canSync => userEmail != null && userEmail!.trim().isNotEmpty;
}

class ReaderNarrationPreferencesController {
  const ReaderNarrationPreferencesController({
    required this.store,
    required this.ttsService,
    required this.playbackCoordinator,
  });

  final ReaderNarrationPreferencesStore store;
  final ReaderTtsService ttsService;
  final ReaderNarrationPlaybackCoordinator playbackCoordinator;

  Future<ReaderNarrationPreferences?> load({
    required ReaderNarrationPreferencesContext context,
  }) async {
    final userEmail = context.userEmail;
    if (!context.canSync || userEmail == null) return null;

    try {
      final preferences = await store.load(userEmail: userEmail);
      if (preferences == null) return null;

      ttsService.restorePreferences(
        language: _languageFromPreferences(preferences.languageMode),
        rate: preferences.rate,
        voiceId: preferences.voiceId,
      );
      return preferences;
    } catch (_) {
      return null;
    }
  }

  Future<ReaderNarrationPreferencesWriteResult> saveCurrent({
    required ReaderNarrationPreferencesContext context,
    String? selectedVoiceId,
  }) async {
    final userEmail = context.userEmail;
    if (!context.canSync || userEmail == null) {
      return ReaderNarrationPreferencesWriteResult.skipped;
    }

    try {
      await store.save(
        userEmail: userEmail,
        preferences: ReaderNarrationPreferences(
          languageMode: ttsService.language.locale,
          rate: ttsService.rate,
          voiceId: selectedVoiceId ?? playbackCoordinator.selectedVoice?.id,
        ),
      );
      return ReaderNarrationPreferencesWriteResult.saved;
    } catch (_) {
      return ReaderNarrationPreferencesWriteResult.failed;
    }
  }

  Future<ReaderNarrationPreferencesWriteResult> changeLanguage({
    required ReaderNarrationPreferencesContext context,
    required ReaderNarrationLanguage language,
  }) async {
    await ttsService.setLanguage(language);
    return saveCurrent(context: context);
  }

  Future<ReaderNarrationPreferencesWriteResult> changeRate({
    required ReaderNarrationPreferencesContext context,
    required double rate,
  }) async {
    await ttsService.setRate(rate);
    return saveCurrent(context: context);
  }

  Future<bool> changeVoice({
    required ReaderNarrationPreferencesContext context,
    required ReaderNarrationVoice voice,
  }) async {
    final selected = await playbackCoordinator.selectVoice(voice);
    if (!selected) return false;

    await saveCurrent(context: context, selectedVoiceId: voice.id);
    return true;
  }

  ReaderNarrationLanguage _languageFromPreferences(String languageMode) {
    return ReaderNarrationLanguage.values.firstWhere(
      (language) => language.locale == languageMode,
      orElse: () => ReaderNarrationLanguage.english,
    );
  }
}

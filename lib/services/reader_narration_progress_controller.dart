import 'reader_narration_progress_repository.dart';

enum ReaderNarrationProgressWriteResult { skipped, saved, cleared, failed }

class ReaderNarrationProgressContext {
  const ReaderNarrationProgressContext({
    required this.userEmail,
    required this.documentKey,
    required this.pdfTitle,
    required this.storagePath,
  });

  final String? userEmail;
  final String documentKey;
  final String pdfTitle;
  final String storagePath;

  bool get canSync => userEmail != null && userEmail!.trim().isNotEmpty;
}

class ReaderNarrationProgressController {
  const ReaderNarrationProgressController({required this.store});

  final ReaderNarrationProgressStore store;

  Future<ReaderNarrationCheckpoint?> load({
    required ReaderNarrationProgressContext context,
    required int pageNumber,
  }) async {
    final userEmail = context.userEmail;
    if (!context.canSync || userEmail == null) return null;

    try {
      return await store.load(
        userEmail: userEmail,
        documentKey: context.documentKey,
        pageNumber: pageNumber,
      );
    } catch (_) {
      return null;
    }
  }

  int startCharacterFor({
    required String text,
    required int targetPageNumber,
    required int? livePageNumber,
    required String liveText,
    required int liveCharacterOffset,
    required bool hasLiveResume,
    ReaderNarrationCheckpoint? savedCheckpoint,
  }) {
    if (text.isEmpty) return 0;

    final hasMatchingLiveResume =
        hasLiveResume && livePageNumber == targetPageNumber && liveText == text;
    if (hasMatchingLiveResume) {
      return _safeCharacterOffset(text, liveCharacterOffset);
    }

    if (savedCheckpoint?.pageNumber == targetPageNumber) {
      return savedCheckpoint!.characterOffsetForText(text);
    }

    return 0;
  }

  Future<ReaderNarrationProgressWriteResult> saveCurrent({
    required ReaderNarrationProgressContext context,
    required int pageNumber,
    required int? activePageNumber,
    required int characterOffset,
    required int textLength,
    required String languageLocale,
    required double rate,
  }) async {
    final userEmail = context.userEmail;
    if (!context.canSync ||
        userEmail == null ||
        activePageNumber != pageNumber ||
        textLength <= 0 ||
        characterOffset <= 0) {
      return ReaderNarrationProgressWriteResult.skipped;
    }

    try {
      if (characterOffset >= textLength) {
        await store.clear(
          userEmail: userEmail,
          documentKey: context.documentKey,
          pageNumber: pageNumber,
        );
        return ReaderNarrationProgressWriteResult.cleared;
      }

      final checkpoint = ReaderNarrationCheckpoint(
        pageNumber: pageNumber,
        characterOffset: characterOffset,
        textLength: textLength,
        languageLocale: languageLocale,
        rate: rate,
      );

      await store.save(
        userEmail: userEmail,
        documentKey: context.documentKey,
        pdfTitle: context.pdfTitle,
        storagePath: context.storagePath,
        checkpoint: checkpoint,
      );
      return ReaderNarrationProgressWriteResult.saved;
    } catch (_) {
      return ReaderNarrationProgressWriteResult.failed;
    }
  }

  int _safeCharacterOffset(String text, int offset) {
    if (text.isEmpty || offset >= text.length) return 0;

    return offset.clamp(0, text.length - 1);
  }
}

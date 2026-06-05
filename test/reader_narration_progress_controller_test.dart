import 'package:ancient_secure_docs/services/reader_narration_progress_controller.dart';
import 'package:ancient_secure_docs/services/reader_narration_progress_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeNarrationProgressStore implements ReaderNarrationProgressStore {
  ReaderNarrationCheckpoint? loadedCheckpoint;
  ReaderNarrationCheckpoint? savedCheckpoint;
  int loadCalls = 0;
  int saveCalls = 0;
  int clearCalls = 0;
  bool throwOnWrite = false;

  @override
  Future<ReaderNarrationCheckpoint?> load({
    required String userEmail,
    required String documentKey,
    required int pageNumber,
  }) async {
    loadCalls++;
    return loadedCheckpoint;
  }

  @override
  Future<void> save({
    required String userEmail,
    required String documentKey,
    required String pdfTitle,
    required String storagePath,
    required ReaderNarrationCheckpoint checkpoint,
  }) async {
    if (throwOnWrite) throw StateError('offline');
    saveCalls++;
    savedCheckpoint = checkpoint;
  }

  @override
  Future<void> clear({
    required String userEmail,
    required String documentKey,
    required int pageNumber,
  }) async {
    if (throwOnWrite) throw StateError('offline');
    clearCalls++;
  }
}

const progressContext = ReaderNarrationProgressContext(
  userEmail: 'reader@example.com',
  documentKey: 'document-1',
  pdfTitle: 'Protected PDF',
  storagePath: 'vault/protected.pdf',
);

void main() {
  test('loads a saved checkpoint when a user can sync progress', () async {
    final store = FakeNarrationProgressStore()
      ..loadedCheckpoint = const ReaderNarrationCheckpoint(
        pageNumber: 4,
        characterOffset: 30,
        textLength: 100,
        languageLocale: 'en-US',
        rate: 0.8,
      );
    final controller = ReaderNarrationProgressController(store: store);

    final checkpoint = await controller.load(
      context: progressContext,
      pageNumber: 4,
    );

    expect(checkpoint?.progressPercent, 30);
    expect(store.loadCalls, 1);
  });

  test('does not load progress for an anonymous user', () async {
    final store = FakeNarrationProgressStore();
    final controller = ReaderNarrationProgressController(store: store);

    final checkpoint = await controller.load(
      context: const ReaderNarrationProgressContext(
        userEmail: null,
        documentKey: 'document-1',
        pdfTitle: 'Protected PDF',
        storagePath: 'vault/protected.pdf',
      ),
      pageNumber: 4,
    );

    expect(checkpoint, isNull);
    expect(store.loadCalls, 0);
  });

  test('prefers live resume progress over older saved progress', () {
    final controller = ReaderNarrationProgressController(
      store: FakeNarrationProgressStore(),
    );
    const text = 'Protected narration text.';
    const checkpoint = ReaderNarrationCheckpoint(
      pageNumber: 2,
      characterOffset: 5,
      textLength: 25,
      languageLocale: 'en-US',
      rate: 0.5,
    );

    final offset = controller.startCharacterFor(
      text: text,
      targetPageNumber: 2,
      livePageNumber: 2,
      liveText: text,
      liveCharacterOffset: 12,
      hasLiveResume: true,
      savedCheckpoint: checkpoint,
    );

    expect(offset, 12);
  });

  test('uses saved progress when live progress is not available', () {
    final controller = ReaderNarrationProgressController(
      store: FakeNarrationProgressStore(),
    );
    const text = 'Protected narration text.';
    const checkpoint = ReaderNarrationCheckpoint(
      pageNumber: 2,
      characterOffset: 9,
      textLength: 25,
      languageLocale: 'en-US',
      rate: 0.5,
    );

    final offset = controller.startCharacterFor(
      text: text,
      targetPageNumber: 2,
      livePageNumber: null,
      liveText: '',
      liveCharacterOffset: 0,
      hasLiveResume: false,
      savedCheckpoint: checkpoint,
    );

    expect(offset, 9);
  });

  test('saves partial current progress', () async {
    final store = FakeNarrationProgressStore();
    final controller = ReaderNarrationProgressController(store: store);

    final result = await controller.saveCurrent(
      context: progressContext,
      pageNumber: 3,
      activePageNumber: 3,
      characterOffset: 40,
      textLength: 100,
      languageLocale: 'en-US',
      rate: 0.75,
    );

    expect(result, ReaderNarrationProgressWriteResult.saved);
    expect(store.saveCalls, 1);
    expect(store.savedCheckpoint?.progressPercent, 40);
    expect(store.clearCalls, 0);
  });

  test('clears saved progress when narration reaches the end', () async {
    final store = FakeNarrationProgressStore();
    final controller = ReaderNarrationProgressController(store: store);

    final result = await controller.saveCurrent(
      context: progressContext,
      pageNumber: 3,
      activePageNumber: 3,
      characterOffset: 100,
      textLength: 100,
      languageLocale: 'en-US',
      rate: 0.75,
    );

    expect(result, ReaderNarrationProgressWriteResult.cleared);
    expect(store.clearCalls, 1);
    expect(store.saveCalls, 0);
  });

  test('skips progress writes that do not match the active page', () async {
    final store = FakeNarrationProgressStore();
    final controller = ReaderNarrationProgressController(store: store);

    final result = await controller.saveCurrent(
      context: progressContext,
      pageNumber: 3,
      activePageNumber: 4,
      characterOffset: 40,
      textLength: 100,
      languageLocale: 'en-US',
      rate: 0.75,
    );

    expect(result, ReaderNarrationProgressWriteResult.skipped);
    expect(store.saveCalls, 0);
    expect(store.clearCalls, 0);
  });

  test('reports failed progress writes without throwing', () async {
    final store = FakeNarrationProgressStore()..throwOnWrite = true;
    final controller = ReaderNarrationProgressController(store: store);

    final result = await controller.saveCurrent(
      context: progressContext,
      pageNumber: 3,
      activePageNumber: 3,
      characterOffset: 40,
      textLength: 100,
      languageLocale: 'en-US',
      rate: 0.75,
    );

    expect(result, ReaderNarrationProgressWriteResult.failed);
  });
}

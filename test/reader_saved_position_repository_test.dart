import 'package:ancient_secure_docs/services/reader_saved_position_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads saved position data with a safe page number', () {
    final position = ReaderSavedPosition.fromMap({
      'userEmail': 'reader@example.com',
      'pdfTitle': 'Protected Guide.pdf',
      'documentKey': 'vault_pdfs/protected-guide.pdf',
      'storagePath': 'vault_pdfs/protected-guide.pdf',
      'pageNumber': '0',
    }, id: 'saved-position-1');

    expect(position.id, 'saved-position-1');
    expect(position.userEmail, 'reader@example.com');
    expect(position.pdfTitle, 'Protected Guide.pdf');
    expect(position.documentKey, 'vault_pdfs/protected-guide.pdf');
    expect(position.storagePath, 'vault_pdfs/protected-guide.pdf');
    expect(position.pageNumber, 1);
  });

  test('sorts saved positions newest first and keeps pending writes last', () {
    final older = ReaderSavedPosition.fromMap({
      'pageNumber': 2,
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(1000),
    }, id: 'older');
    final pending = ReaderSavedPosition.fromMap({
      'pageNumber': 3,
    }, id: 'pending');
    final newer = ReaderSavedPosition.fromMap({
      'pageNumber': 4,
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(2000),
    }, id: 'newer');

    final sorted = ReaderSavedPosition.sortNewest([older, pending, newer]);

    expect(sorted.map((position) => position.id), [
      'newer',
      'older',
      'pending',
    ]);
  });

  test('sorts automatically updated progress by its latest timestamp', () {
    final olderManual = ReaderSavedPosition.fromMap({
      'pageNumber': 4,
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(2000),
    }, id: 'manual');
    final automaticProgress = ReaderSavedPosition.fromMap({
      'pageNumber': 18,
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(1000),
      'updatedAt': Timestamp.fromMillisecondsSinceEpoch(3000),
    }, id: 'automatic');

    expect(
      ReaderSavedPosition.sortNewest([
        olderManual,
        automaticProgress,
      ]).first.pageNumber,
      18,
    );
  });

  test('builds a stable per-user per-document automatic progress id', () {
    const first = ReaderSavedPositionDraft(
      userEmail: 'Reader@Example.com',
      pdfTitle: 'Guide.pdf',
      documentKey: 'vault/guide.pdf',
      pageNumber: 8,
    );
    const laterPage = ReaderSavedPositionDraft(
      userEmail: 'reader@example.com',
      pdfTitle: 'Renamed Guide.pdf',
      documentKey: 'vault/guide.pdf',
      pageNumber: 22,
    );

    expect(
      readerLatestPositionDocumentId(first),
      readerLatestPositionDocumentId(laterPage),
    );
  });

  test('normalizes automatic reading-position data', () {
    const draft = ReaderSavedPositionDraft(
      userEmail: ' reader@example.com ',
      pdfTitle: ' Guide.pdf ',
      documentKey: ' vault/guide.pdf ',
      pageNumber: 0,
    );
    final data = readerSavedPositionData(draft, updatedAt: 'server-time');

    expect(data['userEmail'], 'reader@example.com');
    expect(data['pdfTitle'], 'Guide.pdf');
    expect(data['documentKey'], 'vault/guide.pdf');
    expect(data['pageNumber'], 1);
    expect(data['updatedAt'], 'server-time');
  });
  test('applies saved positions for direct document opens', () {
    final shouldApply =
        ReaderSavedPositionResumePolicy.shouldApplySavedPosition(
          initialPage: 0,
          initialSearchQuery: '',
          openSource: 'free_dashboard',
        );

    expect(shouldApply, isTrue);
  });

  test('does not apply saved positions over search-result page jumps', () {
    final shouldApply =
        ReaderSavedPositionResumePolicy.shouldApplySavedPosition(
          initialPage: 12,
          initialSearchQuery: 'finance',
          openSource: 'global_search_result',
        );

    expect(shouldApply, isFalse);
  });

  test(
    'does not apply saved positions for search results with invalid pages',
    () {
      final shouldApply =
          ReaderSavedPositionResumePolicy.shouldApplySavedPosition(
            initialPage: 0,
            initialSearchQuery: 'finance',
            openSource: 'global_search_result',
          );

      expect(shouldApply, isFalse);
    },
  );

  test('does not apply saved positions over explicit page opens', () {
    final shouldApply =
        ReaderSavedPositionResumePolicy.shouldApplySavedPosition(
          initialPage: 7,
          initialSearchQuery: '',
          openSource: 'direct_open',
        );

    expect(shouldApply, isFalse);
  });
}

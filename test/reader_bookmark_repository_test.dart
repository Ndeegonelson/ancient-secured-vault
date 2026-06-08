import 'package:ancient_secure_docs/services/reader_bookmark_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads bookmark data with a safe page number', () {
    final bookmark = ReaderBookmark.fromMap({
      'userEmail': 'reader@example.com',
      'pdfTitle': 'Protected Guide.pdf',
      'label': 'Funding terms',
      'documentKey': 'vault_pdfs/protected-guide.pdf',
      'storagePath': 'vault_pdfs/protected-guide.pdf',
      'pageNumber': '0',
    }, id: 'bookmark-1');

    expect(bookmark.id, 'bookmark-1');
    expect(bookmark.userEmail, 'reader@example.com');
    expect(bookmark.pdfTitle, 'Protected Guide.pdf');
    expect(bookmark.label, 'Funding terms');
    expect(bookmark.displayLabel, 'Funding terms');
    expect(bookmark.documentKey, 'vault_pdfs/protected-guide.pdf');
    expect(bookmark.storagePath, 'vault_pdfs/protected-guide.pdf');
    expect(bookmark.pageNumber, 1);
  });

  test('uses page number as the display label when label is empty', () {
    final bookmark = ReaderBookmark.fromMap({
      'label': '   ',
      'pageNumber': 7,
    }, id: 'bookmark-7');

    expect(bookmark.displayLabel, 'Page 7');
  });

  test('sorts updated bookmarks before older saved bookmarks', () {
    final older = ReaderBookmark.fromMap({
      'label': 'Older',
      'pageNumber': 2,
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(1000),
    }, id: 'older');
    final updated = ReaderBookmark.fromMap({
      'label': 'Updated',
      'pageNumber': 3,
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(500),
      'updatedAt': Timestamp.fromMillisecondsSinceEpoch(3000),
    }, id: 'updated');
    final pending = ReaderBookmark.fromMap({
      'label': 'Pending',
      'pageNumber': 4,
    }, id: 'pending');

    final sorted = ReaderBookmark.sortNewest([older, pending, updated]);

    expect(sorted.map((bookmark) => bookmark.id), [
      'updated',
      'older',
      'pending',
    ]);
  });

  test('searches bookmarks by label and page', () {
    final funding = ReaderBookmark.fromMap({
      'label': 'Funding terms',
      'pageNumber': 12,
    }, id: 'funding');
    final admin = ReaderBookmark.fromMap({
      'label': 'Admin checklist',
      'pageNumber': 4,
    }, id: 'admin');

    expect(funding.matchesSearch('funding'), isTrue);
    expect(funding.matchesSearch('page 12'), isTrue);
    expect(funding.matchesSearch('missing'), isFalse);
    expect(
      ReaderBookmark.search([
        funding,
        admin,
      ], 'checklist').map((bookmark) => bookmark.id),
      ['admin'],
    );
  });
}

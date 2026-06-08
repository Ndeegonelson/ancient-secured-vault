import 'package:ancient_secure_docs/services/reader_highlight_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads highlight data with safe defaults for older records', () {
    final highlight = ReaderHighlight.fromMap({
      'userEmail': 'reader@example.com',
      'pdfTitle': 'Protected Guide.pdf',
      'selectedText': 'Important passage',
      'color': 'green',
      'documentKey': 'vault_pdfs/protected-guide.pdf',
      'storagePath': 'vault_pdfs/protected-guide.pdf',
      'pageNumber': '0',
    }, id: 'highlight-1');

    expect(highlight.id, 'highlight-1');
    expect(highlight.userEmail, 'reader@example.com');
    expect(highlight.pdfTitle, 'Protected Guide.pdf');
    expect(highlight.selectedText, 'Important passage');
    expect(highlight.color, 'green');
    expect(highlight.displayColor, 'Green');
    expect(highlight.documentKey, 'vault_pdfs/protected-guide.pdf');
    expect(highlight.storagePath, 'vault_pdfs/protected-guide.pdf');
    expect(highlight.pageNumber, 1);
  });

  test('falls back to yellow for unknown highlight colors', () {
    final highlight = ReaderHighlight.fromMap({
      'selectedText': 'Legacy highlight',
      'color': 'purple',
      'pageNumber': 4,
    }, id: 'legacy');

    expect(highlight.color, 'yellow');
    expect(highlight.displayColor, 'Yellow');
  });

  test('sorts highlights from newest to oldest', () {
    final older = ReaderHighlight.fromMap({
      'selectedText': 'Older highlight',
      'pageNumber': 2,
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(1000),
    }, id: 'older');
    final newer = ReaderHighlight.fromMap({
      'selectedText': 'Newer highlight',
      'pageNumber': 3,
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(3000),
    }, id: 'newer');
    final pending = ReaderHighlight.fromMap({
      'selectedText': 'Pending highlight',
      'pageNumber': 4,
    }, id: 'pending');

    final sorted = ReaderHighlight.sortNewest([older, pending, newer]);

    expect(sorted.map((highlight) => highlight.id), [
      'newer',
      'older',
      'pending',
    ]);
  });

  test('searches highlights by text, page, and color', () {
    final finance = ReaderHighlight.fromMap({
      'selectedText': 'Central bank policy reference',
      'color': 'blue',
      'pageNumber': 12,
    }, id: 'finance');
    final admin = ReaderHighlight.fromMap({
      'selectedText': 'Send to admin team.',
      'color': 'pink',
      'pageNumber': 4,
    }, id: 'admin');

    expect(finance.matchesSearch('bank policy'), isTrue);
    expect(finance.matchesSearch('blue'), isTrue);
    expect(finance.matchesSearch('page 12'), isTrue);
    expect(finance.matchesSearch('missing'), isFalse);
    expect(
      ReaderHighlight.search([
        finance,
        admin,
      ], 'pink').map((highlight) => highlight.id),
      ['admin'],
    );
  });
}

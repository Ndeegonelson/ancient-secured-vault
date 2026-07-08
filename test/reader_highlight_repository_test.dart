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
      'note': 'Compare this with the funding memo.',
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
    expect(highlight.note, 'Compare this with the funding memo.');
    expect(highlight.hasNote, isTrue);
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

  test('uses document key when watching document highlights', () {
    final lookup = ReaderHighlightDocumentLookup.from(
      documentKey: ' vault_pdfs/protected-guide.pdf ',
      pdfTitle: 'Protected Guide.pdf',
    );

    expect(lookup.usesDocumentKey, isTrue);
    expect(lookup.field, 'documentKey');
    expect(lookup.value, 'vault_pdfs/protected-guide.pdf');
  });

  test('falls back to PDF title when watching legacy highlights', () {
    final lookup = ReaderHighlightDocumentLookup.from(
      documentKey: ' ',
      pdfTitle: ' Protected Guide.pdf ',
    );

    expect(lookup.usesDocumentKey, isFalse);
    expect(lookup.field, 'pdfTitle');
    expect(lookup.value, 'Protected Guide.pdf');
  });

  test('rejects empty highlight selections before saving', () {
    expect(
      () => readerHighlightSaveData(
        const ReaderHighlightDraft(
          userEmail: 'reader@example.com',
          pdfTitle: 'Protected Guide.pdf',
          selectedText: '   ',
          pageNumber: 2,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('trims valid highlight drafts before saving', () {
    final data = readerHighlightSaveData(
      const ReaderHighlightDraft(
        userEmail: ' reader@example.com ',
        pdfTitle: ' Protected Guide.pdf ',
        selectedText: ' Important passage ',
        color: ' blue ',
        note: '   ',
        documentKey: ' vault_pdfs/protected-guide.pdf ',
        storagePath: ' vault_pdfs/protected-guide.pdf ',
        pageNumber: 0,
      ),
      createdAt: 'now',
    );

    expect(data['userEmail'], 'reader@example.com');
    expect(data['pdfTitle'], 'Protected Guide.pdf');
    expect(data['selectedText'], 'Important passage');
    expect(data['color'], 'blue');
    expect(data['note'], '');
    expect(data['documentKey'], 'vault_pdfs/protected-guide.pdf');
    expect(data['storagePath'], 'vault_pdfs/protected-guide.pdf');
    expect(data['pageNumber'], 1);
    expect(data['createdAt'], 'now');
  });

  test('sorts updated highlights before older saved highlights', () {
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
    final updated = ReaderHighlight.fromMap({
      'selectedText': 'Updated highlight',
      'pageNumber': 5,
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(500),
      'updatedAt': Timestamp.fromMillisecondsSinceEpoch(5000),
    }, id: 'updated');
    final pending = ReaderHighlight.fromMap({
      'selectedText': 'Pending highlight',
      'pageNumber': 4,
    }, id: 'pending');

    final sorted = ReaderHighlight.sortNewest([older, pending, newer, updated]);

    expect(sorted.map((highlight) => highlight.id), [
      'updated',
      'newer',
      'older',
      'pending',
    ]);
  });

  test('searches highlights by text, page, and color', () {
    final finance = ReaderHighlight.fromMap({
      'selectedText': 'Central bank policy reference',
      'note': 'Review with treasury team.',
      'color': 'blue',
      'pageNumber': 12,
    }, id: 'finance');
    final admin = ReaderHighlight.fromMap({
      'selectedText': 'Send to admin team.',
      'color': 'pink',
      'pageNumber': 4,
    }, id: 'admin');

    expect(finance.matchesSearch('bank policy'), isTrue);
    expect(finance.matchesSearch('treasury'), isTrue);
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

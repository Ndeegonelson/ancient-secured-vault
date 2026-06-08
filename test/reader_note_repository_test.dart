import 'package:ancient_secure_docs/services/reader_note_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads note data with safe defaults for future reader features', () {
    final note = ReaderNote.fromMap({
      'userEmail': 'reader@example.com',
      'pdfTitle': 'Protected Guide.pdf',
      'selectedText': 'Important passage',
      'note': 'Review this later.',
      'color': 'green',
      'documentKey': 'vault_pdfs/protected-guide.pdf',
      'storagePath': 'vault_pdfs/protected-guide.pdf',
      'category': 'Research',
      'pageNumber': '0',
    }, id: 'note-1');

    expect(note.id, 'note-1');
    expect(note.userEmail, 'reader@example.com');
    expect(note.pdfTitle, 'Protected Guide.pdf');
    expect(note.selectedText, 'Important passage');
    expect(note.note, 'Review this later.');
    expect(note.color, 'green');
    expect(note.documentKey, 'vault_pdfs/protected-guide.pdf');
    expect(note.storagePath, 'vault_pdfs/protected-guide.pdf');
    expect(note.category, 'Research');
    expect(note.pageNumber, 1);
  });

  test('sorts updated notes before older saved notes', () {
    final older = ReaderNote.fromMap({
      'note': 'Older note',
      'pageNumber': 2,
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(1000),
    }, id: 'older');
    final updated = ReaderNote.fromMap({
      'note': 'Updated note',
      'pageNumber': 3,
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(500),
      'updatedAt': Timestamp.fromMillisecondsSinceEpoch(3000),
    }, id: 'updated');
    final pending = ReaderNote.fromMap({
      'note': 'Pending note',
      'pageNumber': 4,
    }, id: 'pending');

    final sorted = ReaderNote.sortNewest([older, pending, updated]);

    expect(sorted.map((note) => note.id), ['updated', 'older', 'pending']);
  });
}

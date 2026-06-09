import 'package:ancient_secure_docs/services/reader_highlight_repository.dart';
import 'package:ancient_secure_docs/services/reader_note_repository.dart';
import 'package:ancient_secure_docs/services/reader_saved_position_repository.dart';
import 'package:ancient_secure_docs/services/reader_workspace_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('filters saved positions by page label or number', () {
    const first = ReaderSavedPosition(
      id: 'first',
      userEmail: 'reader@example.com',
      pdfTitle: 'Protected.pdf',
      pageNumber: 3,
    );
    const second = ReaderSavedPosition(
      id: 'second',
      userEmail: 'reader@example.com',
      pdfTitle: 'Protected.pdf',
      pageNumber: 12,
    );

    expect(ReaderWorkspaceFilters.filterPositions([first, second], 'page 12'), [
      second,
    ]);
    expect(ReaderWorkspaceFilters.filterPositions([first, second], '3'), [
      first,
    ]);
  });

  test('filters highlights by search text and selected color', () {
    final yellow = ReaderHighlight.fromMap({
      'selectedText': 'Important loan detail',
      'color': 'yellow',
      'pageNumber': 2,
    });
    final green = ReaderHighlight.fromMap({
      'selectedText': 'Operational note',
      'color': 'green',
      'pageNumber': 5,
    });

    expect(
      ReaderWorkspaceFilters.filterHighlights(
        highlights: [yellow, green],
        query: 'note',
        colorFilter: 'Green',
      ),
      [green],
    );
    expect(
      ReaderWorkspaceFilters.filterHighlights(
        highlights: [yellow, green],
        query: 'loan',
        colorFilter: 'Green',
      ),
      isEmpty,
    );
  });

  test('filters notes by search text and category', () {
    final research = ReaderNote.fromMap({
      'note': 'Review finance passage',
      'category': 'Research',
      'pageNumber': 4,
    });
    final operations = ReaderNote.fromMap({
      'note': 'Call admin team',
      'category': 'Operations',
      'pageNumber': 8,
    });

    expect(
      ReaderWorkspaceFilters.filterNotes(
        notes: [research, operations],
        query: 'review',
        categoryFilter: 'Research',
      ),
      [research],
    );
    expect(
      ReaderWorkspaceFilters.filterNotes(
        notes: [research, operations],
        query: '',
        categoryFilter: 'Operations',
      ),
      [operations],
    );
  });

  test('builds compact active workspace filter labels', () {
    expect(
      ReaderWorkspaceFilters.activeFilterLabels(
        query: ' treasury ',
        highlightColorFilter: 'Green',
        noteCategoryFilter: 'Operations',
      ),
      [
        'Search: treasury',
        'Highlight color: Green',
        'Note category: Operations',
      ],
    );
    expect(ReaderWorkspaceFilters.activeFilterLabels(), isEmpty);
    expect(
      ReaderWorkspaceFilters.hasActiveFilters(highlightColorFilter: 'Blue'),
      isTrue,
    );
    expect(ReaderWorkspaceFilters.hasActiveFilters(), isFalse);
  });

  test('labels filtered workspace counts against total saved items', () {
    expect(
      ReaderWorkspaceFilters.filteredCountLabel(
        visibleCount: 2,
        totalCount: 5,
        hasActiveFilter: true,
      ),
      '2 of 5',
    );
    expect(
      ReaderWorkspaceFilters.filteredCountLabel(
        visibleCount: 5,
        totalCount: 5,
        hasActiveFilter: true,
      ),
      '5',
    );
    expect(
      ReaderWorkspaceFilters.filteredCountLabel(
        visibleCount: -1,
        totalCount: 5,
      ),
      '0',
    );
  });
}

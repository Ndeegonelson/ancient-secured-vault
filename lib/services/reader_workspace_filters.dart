import 'reader_highlight_repository.dart';
import 'reader_note_repository.dart';
import 'reader_saved_position_repository.dart';

class ReaderWorkspaceFilters {
  const ReaderWorkspaceFilters._();

  static const String allFilter = 'All';

  static bool positionMatchesSearch(
    ReaderSavedPosition position,
    String query,
  ) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;

    final page = position.pageNumber;
    return 'page $page'.contains(normalizedQuery) ||
        page.toString().contains(normalizedQuery);
  }

  static List<ReaderSavedPosition> filterPositions(
    Iterable<ReaderSavedPosition> positions,
    String query,
  ) {
    return positions
        .where((position) => positionMatchesSearch(position, query))
        .toList();
  }

  static List<ReaderHighlight> filterHighlights({
    required Iterable<ReaderHighlight> highlights,
    required String query,
    String colorFilter = allFilter,
  }) {
    final matchingHighlights = ReaderHighlight.search(highlights, query);
    if (colorFilter == allFilter) return matchingHighlights;

    final color = _normalizeHighlightColor(colorFilter);
    return matchingHighlights
        .where((highlight) => highlight.color == color)
        .toList();
  }

  static List<ReaderNote> filterNotes({
    required Iterable<ReaderNote> notes,
    required String query,
    String categoryFilter = allFilter,
  }) {
    final matchingNotes = ReaderNote.search(notes, query);
    if (categoryFilter == allFilter) return matchingNotes;

    return matchingNotes
        .where((note) => note.displayCategory == categoryFilter)
        .toList();
  }

  static List<String> activeFilterLabels({
    String query = '',
    String highlightColorFilter = allFilter,
    String noteCategoryFilter = allFilter,
  }) {
    final labels = <String>[];
    final cleanQuery = query.trim();

    if (cleanQuery.isNotEmpty) {
      labels.add('Search: $cleanQuery');
    }
    if (highlightColorFilter != allFilter) {
      labels.add('Highlight color: $highlightColorFilter');
    }
    if (noteCategoryFilter != allFilter) {
      labels.add('Note category: $noteCategoryFilter');
    }

    return List.unmodifiable(labels);
  }

  static bool hasActiveFilters({
    String query = '',
    String highlightColorFilter = allFilter,
    String noteCategoryFilter = allFilter,
  }) {
    return activeFilterLabels(
      query: query,
      highlightColorFilter: highlightColorFilter,
      noteCategoryFilter: noteCategoryFilter,
    ).isNotEmpty;
  }

  static String _normalizeHighlightColor(String value) {
    final color = value.trim().toLowerCase();
    return switch (color) {
      'green' || 'blue' || 'pink' || 'red' => color,
      _ => 'yellow',
    };
  }
}

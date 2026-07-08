List<String> vaultSearchTerms(String query) {
  final terms = query
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .split(RegExp(r'\s+'))
      .map((term) => term.trim())
      .where((term) => term.length > 2)
      .toSet()
      .toList();

  terms.sort((a, b) {
    final lengthComparison = b.length.compareTo(a.length);
    if (lengthComparison != 0) return lengthComparison;

    return a.compareTo(b);
  });
  return List.unmodifiable(terms);
}

String vaultPrimarySearchTerm(String query) {
  final terms = vaultSearchTerms(query);
  if (terms.isNotEmpty) return terms.first;

  final fallbackTerms = query
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .split(RegExp(r'\s+'))
      .map((term) => term.trim())
      .where((term) => term.isNotEmpty);

  for (final term in fallbackTerms) {
    return term;
  }

  return '';
}

List<String> vaultSearchQueryTerms(String query, {int limit = 4}) {
  assert(limit > 0);

  final terms = vaultSearchTerms(query).take(limit).toList();
  if (terms.isNotEmpty) return List.unmodifiable(terms);

  final fallbackTerm = vaultPrimarySearchTerm(query);
  return fallbackTerm.isEmpty ? const [] : [fallbackTerm];
}

String vaultSearchTermsLabel(String query, {int limit = 4}) {
  final terms = vaultSearchQueryTerms(query, limit: limit);
  if (terms.isEmpty) return 'No searchable terms';

  return 'Matching: ${terms.join(', ')}';
}

String vaultSearchResultsLabel({
  required int visibleCount,
  required int totalCount,
}) {
  final safeVisibleCount = visibleCount < 0 ? 0 : visibleCount;
  final safeTotalCount = totalCount < 0 ? 0 : totalCount;
  final matchLabel = safeVisibleCount == 1 ? 'match' : 'matches';

  if (safeVisibleCount == safeTotalCount) {
    return '$safeVisibleCount $matchLabel';
  }

  return '$safeVisibleCount of $safeTotalCount matches';
}

class VaultSearchResultGroup {
  const VaultSearchResultGroup({
    required this.documentKey,
    required this.title,
    required this.accessLabel,
    required this.categoryLabel,
    required this.matches,
  });

  final String documentKey;
  final String title;
  final String accessLabel;
  final String categoryLabel;
  final List<Map<String, dynamic>> matches;

  int get matchCount => matches.length;

  String get matchCountLabel {
    final label = matchCount == 1 ? 'match' : 'matches';
    return '$matchCount $label';
  }

  String get detailLabel => '$matchCountLabel | $accessLabel | $categoryLabel';
}

List<VaultSearchResultGroup> groupVaultSearchResultsByDocument(
  Iterable<Map<String, dynamic>> results,
) {
  final groupedResults = <String, List<Map<String, dynamic>>>{};
  final firstResultByKey = <String, Map<String, dynamic>>{};

  for (final result in results) {
    final key = _vaultSearchDocumentGroupKey(result, groupedResults.length);
    groupedResults.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(result);
    firstResultByKey.putIfAbsent(key, () => result);
  }

  return groupedResults.entries
      .map((entry) {
        final firstResult =
            firstResultByKey[entry.key] ?? const <String, dynamic>{};
        return VaultSearchResultGroup(
          documentKey: entry.key,
          title: vaultSearchDocumentTitle(firstResult),
          accessLabel: vaultSearchAccessLabel(firstResult['accessLevel']),
          categoryLabel: vaultSearchCategoryLabel(firstResult['category']),
          matches: List.unmodifiable(entry.value),
        );
      })
      .toList(growable: false);
}

String vaultSearchDocumentTitle(Map<String, dynamic> result) {
  final title = result['pdfTitle']?.toString().trim() ?? '';
  return title.isEmpty ? 'Untitled document' : title;
}

String vaultSearchAccessLabel(Object? accessLevel) {
  final normalized = accessLevel?.toString().trim().toLowerCase() ?? '';
  return normalized == 'premium' ? 'Premium' : 'Free';
}

String vaultSearchCategoryLabel(Object? category) {
  final label = category?.toString().trim() ?? '';
  return label.isEmpty ? 'General' : label;
}

String vaultSearchMatchRowLabel(Map<String, dynamic> result) {
  final page = vaultSearchPageNumber(result['pageNumber']);
  return 'Page $page | ${vaultSearchAccessLabel(result['accessLevel'])} | '
      '${vaultSearchCategoryLabel(result['category'])}';
}

int vaultSearchPageNumber(Object? pageNumber) {
  final page = pageNumber is int
      ? pageNumber
      : int.tryParse(pageNumber?.toString() ?? '') ?? 1;
  return page < 1 ? 1 : page;
}

bool vaultTextMatchesSearchTerm(String text, String searchTerm) {
  final normalizedSearchTerm = vaultPrimarySearchTerm(searchTerm);
  if (normalizedSearchTerm.isEmpty) return false;

  return vaultSearchTerms(text).contains(normalizedSearchTerm);
}

bool vaultTextMatchesAnySearchTerm(String text, String query) {
  final textTerms = vaultSearchTerms(text).toSet();
  if (textTerms.isEmpty) return false;

  for (final term in vaultSearchTerms(query)) {
    if (textTerms.contains(term)) return true;
  }

  final fallbackTerm = vaultPrimarySearchTerm(query);
  return fallbackTerm.isNotEmpty && textTerms.contains(fallbackTerm);
}

bool vaultIndexedTermsMatchQuery(Iterable<Object?> values, String query) {
  final indexedTerms = values.map((value) => value.toString()).toSet();
  if (indexedTerms.isEmpty) return false;

  for (final term in vaultSearchTerms(query)) {
    if (indexedTerms.contains(term)) return true;
  }

  final fallbackTerm = vaultPrimarySearchTerm(query);
  return fallbackTerm.isNotEmpty && indexedTerms.contains(fallbackTerm);
}

String vaultBestSnippetKeyword(String text, String query) {
  final cleanText = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  for (final term in vaultSearchTerms(query)) {
    if (cleanText.contains(term)) return term;
  }

  final fallbackTerm = vaultPrimarySearchTerm(query);
  return cleanText.contains(fallbackTerm) ? fallbackTerm : '';
}

int vaultSearchMatchScore({
  required String query,
  String title = '',
  String text = '',
  Iterable<Object?> pageKeywords = const [],
  Iterable<Object?> titleKeywords = const [],
}) {
  final terms = vaultSearchTerms(query);
  if (terms.isEmpty) return 0;

  final normalizedTitle = title.toLowerCase();
  final normalizedText = text.toLowerCase();
  final pageTermSet = pageKeywords.map((value) => value.toString()).toSet();
  final titleTermSet = titleKeywords.map((value) => value.toString()).toSet();
  final phrase = query.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  var score = 0;

  if (phrase.isNotEmpty && normalizedTitle.contains(phrase)) score += 18;
  if (phrase.isNotEmpty && normalizedText.contains(phrase)) score += 8;

  for (final term in terms) {
    if (titleTermSet.contains(term)) score += 12;
    if (pageTermSet.contains(term)) score += 7;
    if (normalizedTitle.contains(term)) score += 5;
    if (normalizedText.contains(term)) score += 2;
  }

  return score;
}

String buildVaultSearchSnippet(
  String text,
  String keyword, {
  int contextCharacters = 70,
}) {
  final cleanText = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final cleanKeyword = keyword.trim();

  if (cleanText.isEmpty) return '';
  if (cleanKeyword.isEmpty) {
    return _trimSnippet(cleanText, 0, contextCharacters * 2);
  }

  final matchIndex = cleanText.toLowerCase().indexOf(
    cleanKeyword.toLowerCase(),
  );

  if (matchIndex < 0) {
    return _trimSnippet(cleanText, 0, contextCharacters * 2);
  }

  final start = (matchIndex - contextCharacters).clamp(0, cleanText.length);
  final end = (matchIndex + cleanKeyword.length + contextCharacters).clamp(
    start,
    cleanText.length,
  );

  return _trimSnippet(cleanText, start, end);
}

String _trimSnippet(String text, int start, int end) {
  final safeStart = start.clamp(0, text.length);
  final safeEnd = end.clamp(safeStart, text.length);
  final prefix = safeStart > 0 ? '... ' : '';
  final suffix = safeEnd < text.length ? ' ...' : '';

  return '$prefix${text.substring(safeStart, safeEnd).trim()}$suffix';
}

String _vaultSearchDocumentGroupKey(
  Map<String, dynamic> result,
  int fallbackIndex,
) {
  final storagePath = result['storagePath']?.toString().trim() ?? '';
  if (storagePath.isNotEmpty) return 'storage:$storagePath';

  final pdfUrl = result['pdfUrl']?.toString().trim() ?? '';
  if (pdfUrl.isNotEmpty) return 'url:$pdfUrl';

  final title = _normalizedVaultSearchGroupValue(result['pdfTitle']);
  if (title.isNotEmpty) return 'title:$title';

  return 'untitled:$fallbackIndex';
}

String _normalizedVaultSearchGroupValue(Object? value) {
  return value?.toString().trim().toLowerCase().replaceAll(
        RegExp(r'\s+'),
        ' ',
      ) ??
      '';
}

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

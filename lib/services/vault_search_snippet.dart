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

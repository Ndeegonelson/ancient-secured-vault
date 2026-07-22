String normalizeNarrationText(String source) {
  if (source.trim().isEmpty) return '';

  var text = source
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\u00AD', '');

  // PDF extractors commonly insert a newline wherever text wraps visually.
  // Rejoin hyphenated words first, then turn single line wraps into spaces.
  text = text.replaceAllMapped(
    RegExp(r'([A-Za-zÀ-ÖØ-öø-ÿ])-\s*\n\s*([A-Za-zÀ-ÖØ-öø-ÿ])'),
    (match) => '${match.group(1)}${match.group(2)}',
  );

  final paragraphs = text
      .split(RegExp(r'\n\s*\n+'))
      .map((paragraph) => paragraph.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((paragraph) => paragraph.isNotEmpty);

  return paragraphs.join('\n\n');
}

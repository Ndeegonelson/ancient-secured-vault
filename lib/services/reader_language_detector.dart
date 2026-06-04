enum ReaderTextLanguage { english, french, unknown }

class ReaderLanguageDetector {
  const ReaderLanguageDetector();

  static const _englishWords = {
    'a',
    'and',
    'are',
    'as',
    'at',
    'be',
    'by',
    'for',
    'from',
    'has',
    'in',
    'is',
    'it',
    'of',
    'on',
    'that',
    'the',
    'this',
    'to',
    'was',
    'were',
    'with',
  };

  static const _frenchWords = {
    'au',
    'aux',
    'avec',
    'ce',
    'ces',
    'dans',
    'de',
    'des',
    'du',
    'elle',
    'en',
    'est',
    'et',
    'il',
    'la',
    'le',
    'les',
    'mais',
    'nous',
    'pour',
    'que',
    'qui',
    'sont',
    'sur',
    'une',
    'vous',
  };

  ReaderTextLanguage detect(String text) {
    final normalized = text.toLowerCase().replaceAll('’', "'");
    final words = RegExp(
      r"[a-zàâçéèêëîïôûùüÿœæ']+",
      caseSensitive: false,
    ).allMatches(normalized).map((match) => match.group(0)!);
    var englishScore = 0;
    var frenchScore = 0;

    for (final word in words) {
      if (_englishWords.contains(word)) englishScore++;
      if (_frenchWords.contains(word)) frenchScore++;
    }

    frenchScore +=
        RegExp(r'[àâçéèêëîïôûùüÿœæ]').allMatches(normalized).length * 2;
    frenchScore += RegExp(
      r"\b(?:l|d|j|qu|n|s|c|m|t)'",
    ).allMatches(normalized).length;

    if (frenchScore >= 2 && frenchScore > englishScore) {
      return ReaderTextLanguage.french;
    }

    if (englishScore >= 2 && englishScore > frenchScore) {
      return ReaderTextLanguage.english;
    }

    return ReaderTextLanguage.unknown;
  }
}

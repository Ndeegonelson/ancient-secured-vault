import 'package:ancient_secure_docs/services/reader_language_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const detector = ReaderLanguageDetector();

  test('detects English educational text', () {
    const text =
        'The document explains how the system works and why it is important '
        'for the reader.';

    expect(detector.detect(text), ReaderTextLanguage.english);
  });

  test('detects French educational text', () {
    const text =
        'Le document explique comment le système fonctionne et pourquoi il '
        'est important pour le lecteur.';

    expect(detector.detect(text), ReaderTextLanguage.french);
  });

  test('returns unknown for text without enough language evidence', () {
    expect(detector.detect('Ancient Secure Docs'), ReaderTextLanguage.unknown);
  });
}

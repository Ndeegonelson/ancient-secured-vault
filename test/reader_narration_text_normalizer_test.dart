import 'package:ancient_secure_docs/services/reader_narration_text_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('joins visual PDF line wraps without inventing pauses', () {
    const extracted =
        'The narrator should read this complete\n'
        'sentence naturally without stopping at every\n'
        'visual line break.';

    expect(
      normalizeNarrationText(extracted),
      'The narrator should read this complete sentence naturally without '
      'stopping at every visual line break.',
    );
  });

  test('rejoins words hyphenated across extracted lines', () {
    expect(
      normalizeNarrationText('A profes-\nsional reading experience.'),
      'A professional reading experience.',
    );
  });

  test('preserves real paragraph boundaries', () {
    expect(
      normalizeNarrationText('First paragraph.\n\nSecond paragraph.'),
      'First paragraph.\n\nSecond paragraph.',
    );
  });
}

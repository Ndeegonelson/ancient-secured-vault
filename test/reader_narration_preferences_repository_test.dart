import 'package:ancient_secure_docs/services/reader_narration_preferences_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads saved narration preferences', () {
    final preferences = ReaderNarrationPreferences.fromMap({
      'languageMode': 'auto',
      'rate': 0.75,
    });

    expect(preferences.languageMode, 'auto');
    expect(preferences.rate, 0.75);
  });

  test('uses safe defaults for invalid stored narration preferences', () {
    final preferences = ReaderNarrationPreferences.fromMap({
      'rate': 'not-a-number',
    });

    expect(preferences.languageMode, 'en-US');
    expect(preferences.rate, 0.5);
  });
}

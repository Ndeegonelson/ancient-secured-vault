import 'package:ancient_secure_docs/services/reader_narration_progress_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads and reports a resumable narration checkpoint', () {
    final checkpoint = ReaderNarrationCheckpoint.fromMap({
      'pageNumber': 12,
      'characterOffset': 250,
      'textLength': 1000,
      'languageLocale': 'en-US',
      'rate': 0.75,
    });

    expect(checkpoint.pageNumber, 12);
    expect(checkpoint.isResumable, isTrue);
    expect(checkpoint.progressPercent, 25);
    expect(checkpoint.languageLocale, 'en-US');
    expect(checkpoint.rate, 0.75);
  });

  test('clamps a saved character offset to the current page text', () {
    const checkpoint = ReaderNarrationCheckpoint(
      pageNumber: 3,
      characterOffset: 20,
      textLength: 30,
      languageLocale: 'en-US',
      rate: 0.5,
    );

    expect(checkpoint.characterOffsetForText('short'), 0);
    expect(checkpoint.characterOffsetForText('a sufficiently long page'), 20);
  });
}

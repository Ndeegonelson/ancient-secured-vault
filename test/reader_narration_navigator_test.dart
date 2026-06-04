import 'package:ancient_secure_docs/services/reader_narration_navigator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const text =
      'CHAPTER ONE\n'
      'Opening sentence. Another sentence.\n\n'
      'Second paragraph begins here. It continues.\n\n'
      'SECTION TWO\n'
      'Final paragraph begins here.';

  test('single backward press moves to the previous paragraph', () {
    final navigator = ReaderNarrationNavigator();
    final secondParagraph = text.indexOf('Second paragraph');
    final result = navigator.target(
      text: text,
      currentOffset: text.indexOf('SECTION TWO'),
      direction: ReaderNarrationDirection.backward,
    );

    expect(result.kind, ReaderNarrationJumpKind.paragraph);
    expect(result.offset, secondParagraph);
  });

  test(
    'repeated backward presses expand from paragraph to section and page',
    () {
      final navigator = ReaderNarrationNavigator();
      final now = DateTime(2026, 6, 4);
      final sectionOffset = text.indexOf('SECTION TWO');

      final first = navigator.target(
        text: text,
        currentOffset: text.length,
        direction: ReaderNarrationDirection.backward,
        now: now,
      );
      final second = navigator.target(
        text: text,
        currentOffset: first.offset,
        direction: ReaderNarrationDirection.backward,
        now: now.add(const Duration(milliseconds: 300)),
      );
      final third = navigator.target(
        text: text,
        currentOffset: second.offset,
        direction: ReaderNarrationDirection.backward,
        now: now.add(const Duration(milliseconds: 600)),
      );

      expect(first.kind, ReaderNarrationJumpKind.paragraph);
      expect(second.kind, ReaderNarrationJumpKind.section);
      expect(second.offset, lessThanOrEqualTo(sectionOffset));
      expect(third.kind, ReaderNarrationJumpKind.pageEdge);
      expect(third.offset, 0);
    },
  );

  test('forward page-edge jump stays inside the readable text', () {
    final navigator = ReaderNarrationNavigator();
    final now = DateTime(2026, 6, 4);

    navigator.target(
      text: text,
      currentOffset: 0,
      direction: ReaderNarrationDirection.forward,
      now: now,
    );
    navigator.target(
      text: text,
      currentOffset: 10,
      direction: ReaderNarrationDirection.forward,
      now: now.add(const Duration(milliseconds: 300)),
    );
    final third = navigator.target(
      text: text,
      currentOffset: 20,
      direction: ReaderNarrationDirection.forward,
      now: now.add(const Duration(milliseconds: 600)),
    );

    expect(third.kind, ReaderNarrationJumpKind.pageEdge);
    expect(third.offset, text.length - 1);
  });
}

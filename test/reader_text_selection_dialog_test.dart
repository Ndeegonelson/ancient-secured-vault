import 'package:ancient_secure_docs/widgets/reader_text_selection_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('clicking a passage enables confirmation', (tester) async {
    String? selectedText;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                selectedText = await showDialog<String>(
                  context: context,
                  builder: (context) {
                    return ReaderTextSelectionDialog(
                      pageNumber: 1,
                      pageText: Future.value(
                        'First passage.\n\nSecond passage.',
                      ),
                    );
                  },
                );
              },
              child: const Text('Open selector'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open selector'));
    await tester.pumpAndSettle();

    final confirmButton = find.widgetWithText(
      FilledButton,
      'Narrate Selection',
    );

    expect(find.text('No passage selected'), findsOneWidget);
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

    await tester.tap(find.text('Second passage.'));
    await tester.pumpAndSettle();

    expect(find.text('15 characters selected'), findsOneWidget);
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNotNull);

    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(selectedText, 'Second passage.');
  });
}

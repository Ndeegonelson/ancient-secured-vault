import 'package:ancient_secure_docs/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Home screen shows the Ancient Secure Docs welcome content',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );

    expect(find.text('Ancient Secure Docs'), findsOneWidget);
    expect(find.text('Welcome to Ancient Secure Docs'), findsOneWidget);
    expect(find.text('ENTER PLATFORM'), findsOneWidget);
  });
}

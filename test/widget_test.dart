import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('landing page wires the responsive hero assets and entry actions', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('Welcome to ANCIENT SECURED VAULT'));
    expect(source, contains('ENTER PLATFORM'));
    expect(source, contains('CREATE TEST ACCOUNT'));
    expect(source, contains('Forgot password?'));
    expect(source, contains('assets/landing/hero_secure_knowledge_vault.png'));
    expect(
      source,
      contains('assets/landing/hero_audio_reader_intelligence.png'),
    );
    expect(source, contains('assets/landing/mobile_secure_pdf_streaming.png'));
    expect(source, contains('assets/landing/mobile_smart_notes.png'));
    expect(source, contains('assets/landing/golden_logo.png'));
  });
}

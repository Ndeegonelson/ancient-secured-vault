import 'package:ancient_secure_docs/services/reader_protection_policy.dart';
import 'package:ancient_secure_docs/services/vault_document_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps standard documents readable without privacy shielding', () {
    const policy = ReaderProtectionPolicy(
      documentAccessLevel: 'free',
      hasActiveSubscription: false,
      isAdmin: false,
    );

    expect(policy.isProtectedDocument, isFalse);
    expect(policy.shouldShowWatermark, isFalse);
    expect(policy.shouldBlurWhenInactive, isFalse);
    expect(policy.shouldDeterCopying, isFalse);
    expect(policy.shouldBlockContextMenu, isFalse);
    expect(policy.shouldBlockClipboardShortcuts, isFalse);
    expect(policy.protectionLabel, 'Standard reader');
    expect(
      policy.shouldBlockShortcut('c', controlOrMetaPressed: true),
      isFalse,
    );
  });

  test('protects premium documents for subscribed readers', () {
    const policy = ReaderProtectionPolicy(
      documentAccessLevel: ' Premium ',
      hasActiveSubscription: true,
      isAdmin: false,
    );

    expect(policy.isProtectedDocument, isTrue);
    expect(policy.shouldShowWatermark, isTrue);
    expect(policy.shouldBlurWhenInactive, isTrue);
    expect(policy.shouldDeterCopying, isTrue);
    expect(policy.shouldBlockContextMenu, isTrue);
    expect(policy.shouldBlockClipboardShortcuts, isTrue);
    expect(policy.hasElevatedAccess, isTrue);
    expect(policy.protectionLabel, 'Premium protected reader');
    expect(policy.inactiveShieldTitle, 'Protected document hidden');
    expect(
      policy.inactiveShieldMessage,
      'Return to this window to continue reading securely.',
    );
    expect(
      policy.protectedActionMessage,
      'Protected reader mode keeps this document inside Ancient Secure Docs.',
    );
    expect(policy.shouldBlockShortcut('c', controlOrMetaPressed: true), isTrue);
    expect(policy.shouldBlockShortcut('P', controlOrMetaPressed: true), isTrue);
    expect(
      policy.shouldBlockShortcut('a', controlOrMetaPressed: true),
      isFalse,
    );
    expect(
      policy.shouldBlockShortcut('c', controlOrMetaPressed: false),
      isFalse,
    );
  });

  test('uses protected image reader when document profile requests it', () {
    const policy = ReaderProtectionPolicy(
      documentAccessLevel: 'free',
      readerMode: vaultReaderModeProtectedImage,
      protectionMode: vaultProtectionModeCopyDeterred,
      hasActiveSubscription: true,
      isAdmin: false,
    );

    expect(policy.isProtectedDocument, isTrue);
    expect(policy.usesProtectedImageReader, isTrue);
    expect(policy.shouldDeterCopying, isTrue);
  });

  test('profile can keep a premium document on the standard reader', () {
    const policy = ReaderProtectionPolicy(
      documentAccessLevel: 'premium',
      readerMode: vaultReaderModeStandardPdf,
      protectionMode: vaultProtectionModeStandard,
      hasActiveSubscription: true,
      isAdmin: false,
    );

    expect(policy.isProtectedDocument, isFalse);
    expect(policy.usesProtectedImageReader, isFalse);
    expect(policy.shouldDeterCopying, isFalse);
  });

  test('old premium documents without profile still use protected images', () {
    const policy = ReaderProtectionPolicy(
      documentAccessLevel: 'premium',
      hasActiveSubscription: true,
      isAdmin: false,
    );

    expect(policy.isProtectedDocument, isTrue);
    expect(policy.usesProtectedImageReader, isTrue);
  });

  test('labels admin protected reader sessions distinctly', () {
    const policy = ReaderProtectionPolicy(
      documentAccessLevel: 'premium',
      hasActiveSubscription: false,
      isAdmin: true,
    );

    expect(policy.hasElevatedAccess, isTrue);
    expect(policy.protectionLabel, 'Admin protected reader');
  });
}

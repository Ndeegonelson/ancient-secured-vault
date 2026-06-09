import 'package:ancient_secure_docs/services/reader_protection_policy.dart';
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
    expect(policy.protectionLabel, 'Standard reader');
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
    expect(policy.hasElevatedAccess, isTrue);
    expect(policy.protectionLabel, 'Premium protected reader');
    expect(policy.inactiveShieldTitle, 'Protected document hidden');
    expect(
      policy.inactiveShieldMessage,
      'Return to this window to continue reading securely.',
    );
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

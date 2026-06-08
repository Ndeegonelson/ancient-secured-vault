import 'package:ancient_secure_docs/services/user_access_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('anonymous or missing user data stays in the free access lane', () {
    final access = UserAccessState.fromFirestore(null);

    expect(access.isAdmin, isFalse);
    expect(access.hasActiveSubscription, isFalse);
    expect(access.accessLevel, 'free');
    expect(access.canAccessMainVault, isFalse);
    expect(access.canManageVault, isFalse);
    expect(access.planLabel, 'Free');
    expect(access.priority, 1);
    expect(access.canOpenPdfWithAccessLevel('free'), isTrue);
    expect(access.canOpenPdfWithAccessLevel('premium'), isFalse);
  });

  test('active subscribers can open protected vault PDFs', () {
    final access = UserAccessState.fromFirestore({
      'role': 'reader',
      'subscriptionStatus': 'active',
      'accessLevel': 'Premium',
    });

    expect(access.isAdmin, isFalse);
    expect(access.hasActiveSubscription, isTrue);
    expect(access.accessLevel, 'premium');
    expect(access.canAccessMainVault, isTrue);
    expect(access.canManageVault, isFalse);
    expect(access.planLabel, 'Premium');
    expect(access.priority, 2);
    expect(access.canOpenPdfWithAccessLevel('premium'), isTrue);
  });

  test('admins can manage the vault without an active subscription', () {
    final access = UserAccessState.fromFirestore({
      'role': 'admin',
      'subscriptionStatus': 'inactive',
      'accessLevel': 'admin',
    });

    expect(access.isAdmin, isTrue);
    expect(access.hasActiveSubscription, isFalse);
    expect(access.canAccessMainVault, isTrue);
    expect(access.canManageVault, isTrue);
    expect(access.planLabel, 'Admin');
    expect(access.priority, 3);
    expect(access.canOpenPdfWithAccessLevel('premium'), isTrue);
  });

  test('unknown document access levels remain readable by default', () {
    const access = UserAccessState();

    expect(access.canOpenPdfWithAccessLevel('public'), isTrue);
    expect(access.canOpenPdfWithAccessLevel(''), isTrue);
  });
}

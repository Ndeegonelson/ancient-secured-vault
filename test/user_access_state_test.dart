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
    final futureExpiry = DateTime.now().add(const Duration(days: 7));
    final access = UserAccessState.fromFirestore({
      'role': 'reader',
      'subscriptionStatus': 'active',
      'accessLevel': 'Premium',
      'subscriptionProvider': 'stripe',
      'subscriptionExpiresAt': futureExpiry.toIso8601String(),
    });

    expect(access.isAdmin, isFalse);
    expect(access.hasActiveSubscription, isTrue);
    expect(access.accessLevel, 'premium');
    expect(access.subscriptionStatus, UserSubscriptionStatus.active);
    expect(access.subscriptionStatusLabel, 'Active');
    expect(access.subscriptionProvider, 'stripe');
    expect(access.canManageStripeBilling, isTrue);
    expect(access.subscriptionExpiresAt, futureExpiry);
    expect(access.hasSubscriptionExpiry, isTrue);
    expect(access.isAdminManagedSubscription, isFalse);
    expect(access.needsAdminRenewalDate, isFalse);
    expect(access.isSubscriptionExpired, isFalse);
    expect(access.canAccessMainVault, isTrue);
    expect(access.canManageVault, isFalse);
    expect(access.planLabel, 'Premium');
    expect(access.priority, 2);
    expect(access.canOpenPdfWithAccessLevel('premium'), isTrue);
  });

  test('non-Stripe premium subscriptions do not open Stripe billing', () {
    final access = UserAccessState.fromFirestore({
      'role': 'reader',
      'subscriptionStatus': 'active',
      'accessLevel': 'premium',
      'subscriptionProvider': 'admin',
    });

    expect(access.canAccessMainVault, isTrue);
    expect(access.canManageStripeBilling, isFalse);
    expect(access.isAdminManagedSubscription, isFalse);
    expect(access.needsAdminRenewalDate, isFalse);
  });

  test('Paystack subscriptions expose provider and reference details', () {
    final access = UserAccessState.fromFirestore({
      'role': 'reader',
      'subscriptionStatus': 'active',
      'accessLevel': 'premium',
      'subscriptionProvider': 'paystack',
      'paystackCustomerId': 'CUS_test',
      'paystackReference': 'paystack-ref-123',
    });

    expect(access.subscriptionProviderLabel, 'Paystack');
    expect(access.subscriptionReference, 'paystack-ref-123');
    expect(access.subscriptionReferenceLabel, 'Paystack ref: paystack-ref-123');
    expect(access.canManageStripeBilling, isFalse);
    expect(access.isAdminManagedSubscription, isTrue);
    expect(access.needsAdminRenewalDate, isTrue);
  });

  test('manual subscriptions expose provider and proof reference', () {
    final access = UserAccessState.fromFirestore({
      'role': 'reader',
      'subscriptionStatus': 'active',
      'accessLevel': 'premium',
      'subscriptionProvider': 'manual',
      'manualPaymentReference': 'MOMO-7788',
    });

    expect(access.subscriptionProviderLabel, 'Manual proof');
    expect(access.subscriptionReference, 'MOMO-7788');
    expect(access.subscriptionReferenceLabel, 'Manual proof: MOMO-7788');
    expect(access.canManageStripeBilling, isFalse);
    expect(access.isAdminManagedSubscription, isTrue);
    expect(access.needsAdminRenewalDate, isTrue);
  });

  test(
    'Paystack subscriptions with expiry do not need renewal date review',
    () {
      final access = UserAccessState.fromFirestore({
        'role': 'reader',
        'subscriptionStatus': 'active',
        'accessLevel': 'premium',
        'subscriptionProvider': 'paystack',
        'subscriptionExpiresAt': DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String(),
      });

      expect(access.hasActiveSubscription, isTrue);
      expect(access.isAdminManagedSubscription, isTrue);
      expect(access.needsAdminRenewalDate, isFalse);
    },
  );

  test('Stripe billing stays available when payment needs attention', () {
    final access = UserAccessState.fromFirestore({
      'role': 'reader',
      'subscriptionStatus': 'pending',
      'accessLevel': 'free',
      'subscriptionProvider': 'stripe',
      'stripeSubscriptionStatus': 'past_due',
      'stripeLastPaymentStatus': 'failed',
    });

    expect(access.hasActiveSubscription, isFalse);
    expect(access.canManageStripeBilling, isTrue);
    expect(access.hasStripePaymentIssue, isTrue);
    expect(access.stripeAttentionLabel, 'Stripe payment needs attention');
  });

  test('trial subscriptions keep protected vault access until they expire', () {
    final access = UserAccessState.fromFirestore({
      'role': 'reader',
      'subscriptionStatus': 'trial',
      'accessLevel': 'premium',
      'subscriptionExpiresAt': DateTime.now()
          .add(const Duration(days: 14))
          .toIso8601String(),
    });

    expect(access.subscriptionStatus, UserSubscriptionStatus.trial);
    expect(access.hasActiveSubscription, isTrue);
    expect(access.canAccessMainVault, isTrue);
    expect(access.planLabel, 'Premium');
    expect(access.isSubscriptionExpiringSoon, isFalse);
  });

  test('subscriptions near expiry are flagged for admin review', () {
    final access = UserAccessState.fromFirestore({
      'role': 'reader',
      'subscriptionStatus': 'active',
      'accessLevel': 'premium',
      'subscriptionExpiresAt': DateTime.now()
          .add(const Duration(days: 3))
          .toIso8601String(),
    });

    expect(access.hasActiveSubscription, isTrue);
    expect(access.isSubscriptionExpired, isFalse);
    expect(access.isSubscriptionExpiringSoon, isTrue);
  });

  test('expired premium subscriptions fall back to free access', () {
    final access = UserAccessState.fromFirestore({
      'role': 'reader',
      'subscriptionStatus': 'active',
      'accessLevel': 'premium',
      'subscriptionExpiresAt': DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String(),
    });

    expect(access.hasActiveSubscription, isFalse);
    expect(access.isSubscriptionExpired, isTrue);
    expect(access.canAccessMainVault, isFalse);
    expect(access.planLabel, 'Free');
  });

  test('pending and cancelled subscriptions do not unlock the main vault', () {
    for (final status in ['pending', 'cancelled']) {
      final access = UserAccessState.fromFirestore({
        'role': 'reader',
        'subscriptionStatus': status,
        'accessLevel': 'premium',
      });

      expect(access.hasActiveSubscription, isFalse);
      expect(access.canAccessMainVault, isFalse);
      expect(access.canOpenPdfWithAccessLevel('premium'), isFalse);
    }
  });

  test('legacy premium records remain readable before payment migration', () {
    final access = UserAccessState.fromFirestore({
      'role': 'reader',
      'accessLevel': 'premium',
    });

    expect(access.subscriptionStatus, UserSubscriptionStatus.none);
    expect(access.hasActiveSubscription, isTrue);
    expect(access.needsAdminRenewalDate, isFalse);
    expect(access.canAccessMainVault, isTrue);
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

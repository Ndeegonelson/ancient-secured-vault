import 'package:ancient_secure_docs/services/user_access_repository.dart';
import 'package:ancient_secure_docs/services/user_access_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes user email before loading the access document', () {
    expect(
      UserAccessRepository.emailDocumentId(' Reader@Example.COM '),
      'reader@example.com',
    );
  });

  test('uses an empty document id for anonymous readers', () {
    expect(UserAccessRepository.emailDocumentId(null), isEmpty);
    expect(UserAccessRepository.emailDocumentId('   '), isEmpty);
  });

  test('reads user access records for future subscriber management', () {
    final user = UserAccessRecord.fromMap({
      'displayName': 'Ama Reader',
      'country': 'Ghana',
      'role': 'reader',
      'subscriptionStatus': 'active',
      'accessLevel': 'premium',
    }, email: ' Ama@Example.com ');

    expect(user.email, 'ama@example.com');
    expect(user.displayName, 'Ama Reader');
    expect(user.country, 'Ghana');
    expect(user.access.planLabel, 'Premium');
    expect(user.matches('ama'), isTrue);
    expect(user.matches('ghana'), isTrue);
    expect(user.matches('premium'), isTrue);
    expect(user.matches('active'), isTrue);
    expect(user.matches('blocked'), isFalse);
  });

  test('sorts admins then subscribers then free users for admin review', () {
    final free = UserAccessRecord.fromMap({
      'role': 'reader',
      'subscriptionStatus': 'inactive',
    }, email: 'free@example.com');
    final premium = UserAccessRecord.fromMap({
      'role': 'reader',
      'subscriptionStatus': 'active',
    }, email: 'premium@example.com');
    final admin = UserAccessRecord.fromMap({
      'role': 'admin',
      'subscriptionStatus': 'inactive',
    }, email: 'admin@example.com');

    final sorted = UserAccessRecord.sortForAdminList([free, premium, admin]);

    expect(sorted.map((user) => user.email), [
      'admin@example.com',
      'premium@example.com',
      'free@example.com',
    ]);
  });

  test('summarizes admin, subscriber, and free user counts', () {
    final users = [
      UserAccessRecord.fromMap({
        'role': 'admin',
        'subscriptionStatus': 'inactive',
      }, email: 'admin@example.com'),
      UserAccessRecord.fromMap({
        'role': 'reader',
        'subscriptionStatus': 'active',
      }, email: 'premium@example.com'),
      UserAccessRecord.fromMap({
        'role': 'reader',
        'subscriptionStatus': 'inactive',
      }, email: 'free@example.com'),
      UserAccessRecord.fromMap({
        'role': 'reader',
        'subscriptionStatus': 'trial',
        'accessLevel': 'premium',
      }, email: 'trial@example.com'),
      UserAccessRecord.fromMap({
        'role': 'reader',
        'subscriptionStatus': 'pending',
        'accessLevel': 'premium',
      }, email: 'pending@example.com'),
      UserAccessRecord.fromMap({
        'role': 'reader',
        'subscriptionStatus': 'expired',
        'accessLevel': 'premium',
      }, email: 'expired@example.com'),
      UserAccessRecord.fromMap({
        'role': 'reader',
        'subscriptionStatus': 'cancelled',
        'accessLevel': 'premium',
      }, email: 'cancelled@example.com'),
      UserAccessRecord.fromMap({
        'role': 'reader',
        'subscriptionStatus': 'active',
        'accessLevel': 'premium',
        'subscriptionProvider': 'paystack',
      }, email: 'missing-renewal@example.com'),
    ];

    final summary = UserAccessSummary.fromUsers(users);

    expect(summary.totalCount, 8);
    expect(summary.adminCount, 1);
    expect(summary.premiumCount, 3);
    expect(summary.freeCount, 4);
    expect(summary.trialCount, 1);
    expect(summary.pendingCount, 1);
    expect(summary.expiredCount, 1);
    expect(summary.cancelledCount, 1);
    expect(summary.expiredByDateCount, 0);
    expect(summary.expiringSoonCount, 0);
    expect(summary.missingRenewalDateCount, 1);
    expect(summary.hasSubscriptionAttention, isTrue);
    expect(summary.subscriptionReviewCount, 4);
    expect(userAccessSubscriptionAttentionParts(summary), [
      '1 missing renewal date',
      '1 pending',
      '1 expired',
      '1 cancelled',
    ]);
    expect(
      userAccessSubscriptionAttentionLabel(summary),
      '1 missing renewal date | 1 pending | 1 expired | 1 cancelled',
    );
    expect(summary.hasUsers, isTrue);
    expect(summary.hasRecentSubscriptionChanges, isFalse);
    expect(summary.users.map((user) => user.email), [
      'admin@example.com',
      'missing-renewal@example.com',
      'premium@example.com',
      'trial@example.com',
      'cancelled@example.com',
      'expired@example.com',
      'free@example.com',
      'pending@example.com',
    ]);
  });

  test('summarizes subscriptions that expire by date', () {
    final summary = UserAccessSummary.fromUsers([
      UserAccessRecord.fromMap({
        'role': 'reader',
        'subscriptionStatus': 'active',
        'accessLevel': 'premium',
        'subscriptionExpiresAt': DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
      }, email: 'expired-by-date@example.com'),
      UserAccessRecord.fromMap({
        'role': 'reader',
        'subscriptionStatus': 'trial',
        'accessLevel': 'premium',
        'subscriptionExpiresAt': DateTime.now()
            .add(const Duration(days: 2))
            .toIso8601String(),
      }, email: 'soon@example.com'),
    ]);

    expect(summary.premiumCount, 1);
    expect(summary.freeCount, 1);
    expect(summary.expiredByDateCount, 1);
    expect(summary.expiringSoonCount, 1);
    expect(summary.subscriptionReviewCount, 2);
    expect(summary.hasSubscriptionAttention, isTrue);
    expect(userAccessSubscriptionAttentionParts(summary), [
      '1 expired by date',
      '1 expiring soon',
    ]);
  });

  test('summarizes admin-managed subscriptions missing renewal dates', () {
    final summary = UserAccessSummary.fromUsers([
      UserAccessRecord.fromMap({
        'role': 'reader',
        'subscriptionStatus': 'active',
        'accessLevel': 'premium',
        'subscriptionProvider': 'manual',
      }, email: 'manual@example.com'),
      UserAccessRecord.fromMap({
        'role': 'reader',
        'subscriptionStatus': 'active',
        'accessLevel': 'premium',
        'subscriptionProvider': 'paystack',
        'subscriptionExpiresAt': DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String(),
      }, email: 'paystack@example.com'),
      UserAccessRecord.fromMap({
        'role': 'reader',
        'accessLevel': 'premium',
      }, email: 'legacy@example.com'),
    ]);

    expect(summary.missingRenewalDateCount, 1);
    expect(summary.subscriptionReviewCount, 1);
    expect(
      summary.filteredUsers(subscriptionReviewOnly: true).single.email,
      ['manual@example.com'].single,
    );
    expect(userAccessSubscriptionAttentionParts(summary), [
      '1 missing renewal date',
    ]);
  });

  test('filters summary users by search text and access plan', () {
    final summary = UserAccessSummary.fromUsers([
      UserAccessRecord.fromMap({
        'displayName': 'Ama Admin',
        'country': 'Ghana',
        'role': 'admin',
        'subscriptionStatus': 'inactive',
      }, email: 'admin@example.com'),
      UserAccessRecord.fromMap({
        'displayName': 'Prem Reader',
        'country': 'Nigeria',
        'role': 'reader',
        'subscriptionStatus': 'active',
      }, email: 'premium@example.com'),
      UserAccessRecord.fromMap({
        'displayName': 'Free Reader',
        'country': 'Ghana',
        'role': 'reader',
        'subscriptionStatus': 'inactive',
      }, email: 'free@example.com'),
      UserAccessRecord.fromMap({
        'displayName': 'Pending Reader',
        'country': 'Ghana',
        'role': 'reader',
        'subscriptionStatus': 'pending',
      }, email: 'pending@example.com'),
      UserAccessRecord.fromMap({
        'displayName': 'Soon Reader',
        'country': 'Nigeria',
        'role': 'reader',
        'subscriptionStatus': 'trial',
        'accessLevel': 'premium',
        'subscriptionExpiresAt': DateTime.now()
            .add(const Duration(days: 2))
            .toIso8601String(),
      }, email: 'soon@example.com'),
    ]);

    expect(summary.countryOptions, ['Ghana', 'Nigeria']);
    expect(
      summary
          .filteredUsers(query: 'reader', plan: UserAccessPlan.premium)
          .map((user) => user.email),
      ['premium@example.com', 'soon@example.com'],
    );
    expect(
      summary
          .filteredUsers(plan: UserAccessPlan.free)
          .map((user) => user.email),
      ['free@example.com', 'pending@example.com'],
    );
    expect(summary.filteredUsers(country: 'Ghana').map((user) => user.email), [
      'admin@example.com',
      'free@example.com',
      'pending@example.com',
    ]);
    expect(
      summary
          .filteredUsers(query: 'reader', country: 'Nigeria')
          .map((user) => user.email),
      ['premium@example.com', 'soon@example.com'],
    );
    expect(
      summary
          .filteredUsers(subscriptionStatus: UserSubscriptionStatus.active)
          .map((user) => user.email),
      ['premium@example.com'],
    );
    expect(
      summary
          .filteredUsers(subscriptionReviewOnly: true)
          .map((user) => user.email),
      ['soon@example.com', 'pending@example.com'],
    );
    expect(
      summary
          .filteredUsers(country: 'Nigeria', subscriptionReviewOnly: true)
          .map((user) => user.email),
      ['soon@example.com'],
    );
    expect(summary.filteredUsers(query: 'missing'), isEmpty);
  });

  test('builds active user access filter labels', () {
    expect(
      userAccessActiveFilterLabels(
        query: ' reader ',
        plan: UserAccessPlan.premium,
        country: ' Ghana ',
        subscriptionStatus: UserSubscriptionStatus.active,
        subscriptionReviewOnly: true,
      ),
      [
        'Search: reader',
        'Plan: Premium',
        'Country: Ghana',
        'Subscription: Active',
        'Needs subscription review',
      ],
    );
    expect(userAccessActiveFilterLabels(), isEmpty);
    expect(hasUserAccessFilters(country: 'Ghana'), isTrue);
    expect(
      hasUserAccessFilters(subscriptionStatus: UserSubscriptionStatus.pending),
      isTrue,
    );
    expect(hasUserAccessFilters(subscriptionReviewOnly: true), isTrue);
    expect(hasUserAccessFilters(), isFalse);
  });

  test('labels filtered user access counts against total users', () {
    expect(
      userAccessFilteredCountLabel(
        visibleCount: 2,
        totalCount: 5,
        hasActiveFilter: true,
      ),
      '2 of 5',
    );
    expect(
      userAccessFilteredCountLabel(
        visibleCount: 5,
        totalCount: 5,
        hasActiveFilter: true,
      ),
      '5',
    );
    expect(
      userAccessFilteredCountLabel(
        visibleCount: -1,
        totalCount: -3,
        hasActiveFilter: true,
      ),
      '0',
    );
  });

  test('builds compact access record detail labels', () {
    final premium = UserAccessRecord.fromMap({
      'displayName': 'Ama Reader',
      'country': 'Ghana',
      'role': 'reader',
      'subscriptionStatus': 'active',
    }, email: 'ama@example.com');
    final free = UserAccessRecord.fromMap({
      'role': 'reader',
      'subscriptionStatus': 'inactive',
    }, email: 'free@example.com');

    expect(
      userAccessRecordDetailLabel(
        premium,
        isCurrentUser: true,
        timestampLabel: 'Updated today',
      ),
      'Ama Reader | Ghana | Premium | Subscription: Active | Vault enabled | Current admin | Updated today',
    );
    expect(userAccessRecordDetailParts(free), [
      'Free',
      'Subscription: Inactive',
      'Free vault only',
    ]);
  });

  test('describes subscription expiry in access record details', () {
    String dateLabel(DateTime date) {
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '${date.year}-$month-$day $hour:$minute';
    }

    final soon = DateTime.now().add(const Duration(days: 2));
    final expired = DateTime.now().subtract(const Duration(days: 2));
    final active = UserAccessRecord.fromMap({
      'role': 'reader',
      'subscriptionStatus': 'active',
      'accessLevel': 'premium',
      'subscriptionExpiresAt': soon.toIso8601String(),
    }, email: 'soon@example.com');
    final past = UserAccessRecord.fromMap({
      'role': 'reader',
      'subscriptionStatus': 'active',
      'accessLevel': 'premium',
      'subscriptionExpiresAt': expired.toIso8601String(),
    }, email: 'expired@example.com');
    final pending = UserAccessRecord.fromMap({
      'role': 'reader',
      'subscriptionStatus': 'pending',
    }, email: 'pending@example.com');

    expect(
      userAccessRecordDetailParts(active),
      contains('Expires soon: ${dateLabel(soon)}'),
    );
    expect(
      userAccessRecordDetailParts(active),
      contains('Review: expiring soon'),
    );
    expect(
      userAccessRecordDetailParts(past),
      contains('Expired: ${dateLabel(expired)}'),
    );
    expect(
      userAccessRecordDetailParts(past),
      contains('Review: expired by date'),
    );
    expect(
      userAccessSubscriptionReviewLabel(pending),
      'Review: pending payment',
    );
    expect(userAccessSubscriptionReviewReasons(pending), ['pending payment']);

    final failedStripePayment = UserAccessRecord.fromMap({
      'role': 'reader',
      'subscriptionStatus': 'pending',
      'subscriptionProvider': 'stripe',
      'stripeLastPaymentStatus': 'failed',
    }, email: 'stripe@example.com');
    expect(userAccessSubscriptionReviewReasons(failedStripePayment), [
      'Stripe payment issue',
      'pending payment',
    ]);
  });

  test('includes payment provider and reference in access record details', () {
    final paid = UserAccessRecord.fromMap({
      'role': 'reader',
      'subscriptionStatus': 'active',
      'accessLevel': 'premium',
      'subscriptionProvider': 'paystack',
      'paystackReference': 'paystack-ref-123',
    }, email: 'paid@example.com');

    expect(userAccessRecordDetailParts(paid), contains('Provider: Paystack'));
    expect(
      userAccessRecordDetailParts(paid),
      contains('Paystack ref: paystack-ref-123'),
    );
    expect(
      userAccessRecordDetailParts(paid),
      contains('Review: renewal date missing'),
    );
  });

  test('describes when the access list is capped for display', () {
    expect(
      userAccessListLimitMessage(visibleCount: 25, displayLimit: 20),
      'Showing first 20 users. Narrow filters to review the rest.',
    );
    expect(
      userAccessListLimitMessage(visibleCount: 20, displayLimit: 20),
      isNull,
    );
    expect(
      userAccessListLimitMessage(visibleCount: 2, displayLimit: 0),
      'Showing first 1 user. Narrow filters to review the rest.',
    );
  });

  test('builds Firestore updates for each admin access plan', () {
    expect(UserAccessPlanUpdate.fromPlan(UserAccessPlan.admin).toFirestore(), {
      'role': 'admin',
      'subscriptionStatus': 'active',
      'accessLevel': 'admin',
    });
    expect(
      UserAccessPlanUpdate.fromPlan(UserAccessPlan.premium).toFirestore(),
      {
        'role': 'reader',
        'subscriptionStatus': 'active',
        'accessLevel': 'premium',
      },
    );
    expect(UserAccessPlanUpdate.fromPlan(UserAccessPlan.free).toFirestore(), {
      'role': 'reader',
      'subscriptionStatus': 'inactive',
      'accessLevel': 'free',
    });
  });

  test('builds Firestore updates for subscription status changes', () {
    expect(
      UserSubscriptionStatusUpdate(
        status: UserSubscriptionStatus.pending,
      ).toFirestore(updatedAt: 'now'),
      {'subscriptionStatus': 'pending', 'updatedAt': 'now'},
    );
    expect(
      UserSubscriptionStatusUpdate(
        status: UserSubscriptionStatus.cancelled,
      ).toFirestore(),
      {'subscriptionStatus': 'cancelled'},
    );
  });

  test('builds Firestore updates for subscription expiry changes', () {
    final expiresAt = DateTime(2026, 6, 20, 10, 15);

    expect(
      UserSubscriptionExpiryUpdate(
        expiresAt: expiresAt,
      ).toFirestore(updatedAt: 'now'),
      {'subscriptionExpiresAt': expiresAt, 'updatedAt': 'now'},
    );
    expect(
      const UserSubscriptionExpiryUpdate(
        clearExpiry: true,
      ).toFirestore(deleteValue: 'delete'),
      {'subscriptionExpiresAt': 'delete'},
    );
  });

  test('builds an audit payload for admin access changes', () {
    final draft = UserAccessChangeDraft(
      targetEmail: ' Reader@Example.COM ',
      changedByEmail: ' Admin@Example.COM ',
      previousPlan: UserAccessPlan.free,
      nextPlan: UserAccessPlan.premium,
    );

    expect(draft.toMap(createdAt: 'now'), {
      'targetEmail': 'reader@example.com',
      'changedByEmail': 'admin@example.com',
      'previousPlan': 'free',
      'nextPlan': 'premium',
      'createdAt': 'now',
    });
  });

  test('builds an audit payload for subscription status changes', () {
    final draft = UserSubscriptionStatusChangeDraft(
      targetEmail: ' Reader@Example.COM ',
      changedByEmail: ' Admin@Example.COM ',
      previousStatus: UserSubscriptionStatus.trial,
      nextStatus: UserSubscriptionStatus.active,
    );

    expect(draft.toMap(createdAt: 'now'), {
      'targetEmail': 'reader@example.com',
      'changedByEmail': 'admin@example.com',
      'previousSubscriptionStatus': 'trial',
      'nextSubscriptionStatus': 'active',
      'createdAt': 'now',
    });
  });

  test('builds an audit payload for subscription expiry changes', () {
    final previous = DateTime(2026, 6, 20, 10, 15);
    final next = DateTime(2026, 7, 20, 10, 15);
    final draft = UserSubscriptionExpiryChangeDraft(
      targetEmail: ' Reader@Example.COM ',
      changedByEmail: ' Admin@Example.COM ',
      previousExpiresAt: previous,
      nextExpiresAt: next,
      clearExpiry: false,
    );

    expect(draft.toMap(createdAt: 'now'), {
      'targetEmail': 'reader@example.com',
      'changedByEmail': 'admin@example.com',
      'subscriptionChangeType': 'expiry',
      'previousSubscriptionExpiresAt': previous.toIso8601String(),
      'nextSubscriptionExpiresAt': next.toIso8601String(),
      'createdAt': 'now',
    });
  });

  test('reads recent subscription status change records safely', () {
    final change = UserSubscriptionStatusChangeRecord.fromMap({
      'targetEmail': ' Reader@Example.COM ',
      'changedByEmail': ' Admin@Example.COM ',
      'previousSubscriptionStatus': 'pending',
      'nextSubscriptionStatus': 'active',
      'createdAt': 'now',
    }, id: 'subscription-change-1');

    expect(change.id, 'subscription-change-1');
    expect(change.targetEmail, 'reader@example.com');
    expect(change.changedByEmail, 'admin@example.com');
    expect(change.previousStatus, UserSubscriptionStatus.pending);
    expect(change.nextStatus, UserSubscriptionStatus.active);
    expect(change.isExpiryChange, isFalse);
    expect(userAccessSubscriptionChangeLabel(change), 'Pending to Active');
    expect(change.createdAt, 'now');
  });

  test('reads recent subscription expiry change records safely', () {
    final previous = DateTime(2026, 6, 20, 10, 15);
    final next = DateTime(2026, 7, 20, 10, 15);
    final change = UserSubscriptionStatusChangeRecord.fromMap({
      'targetEmail': ' Reader@Example.COM ',
      'changedByEmail': ' Admin@Example.COM ',
      'subscriptionChangeType': 'expiry',
      'previousSubscriptionExpiresAt': previous.toIso8601String(),
      'nextSubscriptionExpiresAt': next.toIso8601String(),
      'createdAt': 'now',
    }, id: 'subscription-expiry-change-1');

    expect(change.id, 'subscription-expiry-change-1');
    expect(change.targetEmail, 'reader@example.com');
    expect(change.changedByEmail, 'admin@example.com');
    expect(change.isExpiryChange, isTrue);
    expect(change.previousExpiresAt, previous);
    expect(change.nextExpiresAt, next);
    expect(
      userAccessSubscriptionChangeLabel(change),
      'Expiry: 2026-06-20 10:15 to 2026-07-20 10:15',
    );
    expect(change.createdAt, 'now');
  });

  test('carries recent subscription status changes in summaries', () {
    final subscriptionChange = UserSubscriptionStatusChangeRecord.fromMap({
      'targetEmail': ' Reader@Example.COM ',
      'changedByEmail': ' Admin@Example.COM ',
      'previousSubscriptionStatus': 'trial',
      'nextSubscriptionStatus': 'active',
    }, id: 'subscription-change-1');

    final summary = UserAccessSummary.fromUsers(
      [
        UserAccessRecord.fromMap({
          'role': 'reader',
          'subscriptionStatus': 'active',
        }, email: 'reader@example.com'),
      ],
      recentSubscriptionChanges: [subscriptionChange],
    );

    expect(summary.hasRecentSubscriptionChanges, isTrue);
    expect(
      summary.recentSubscriptionChanges.single.nextStatus,
      UserSubscriptionStatus.active,
    );
  });

  test('reads recent admin access change records safely', () {
    final change = UserAccessChangeRecord.fromMap({
      'targetEmail': ' Reader@Example.COM ',
      'changedByEmail': ' Admin@Example.COM ',
      'previousPlan': 'premium',
      'nextPlan': 'admin',
      'createdAt': 'now',
    }, id: 'change-1');

    expect(change.id, 'change-1');
    expect(change.targetEmail, 'reader@example.com');
    expect(change.changedByEmail, 'admin@example.com');
    expect(change.previousPlan, UserAccessPlan.premium);
    expect(change.nextPlan, UserAccessPlan.admin);
    expect(change.createdAt, 'now');
  });
}

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
    ];

    final summary = UserAccessSummary.fromUsers(users);

    expect(summary.totalCount, 7);
    expect(summary.adminCount, 1);
    expect(summary.premiumCount, 2);
    expect(summary.freeCount, 4);
    expect(summary.trialCount, 1);
    expect(summary.pendingCount, 1);
    expect(summary.expiredCount, 1);
    expect(summary.cancelledCount, 1);
    expect(summary.hasSubscriptionAttention, isTrue);
    expect(summary.subscriptionReviewCount, 3);
    expect(userAccessSubscriptionAttentionParts(summary), [
      '1 pending',
      '1 expired',
      '1 cancelled',
    ]);
    expect(
      userAccessSubscriptionAttentionLabel(summary),
      '1 pending | 1 expired | 1 cancelled',
    );
    expect(summary.hasUsers, isTrue);
    expect(summary.users.map((user) => user.email), [
      'admin@example.com',
      'premium@example.com',
      'trial@example.com',
      'cancelled@example.com',
      'expired@example.com',
      'free@example.com',
      'pending@example.com',
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
    ]);

    expect(summary.countryOptions, ['Ghana', 'Nigeria']);
    expect(
      summary
          .filteredUsers(query: 'reader', plan: UserAccessPlan.premium)
          .map((user) => user.email),
      ['premium@example.com'],
    );
    expect(
      summary
          .filteredUsers(plan: UserAccessPlan.free)
          .map((user) => user.email),
      ['free@example.com'],
    );
    expect(summary.filteredUsers(country: 'Ghana').map((user) => user.email), [
      'admin@example.com',
      'free@example.com',
    ]);
    expect(
      summary
          .filteredUsers(query: 'reader', country: 'Nigeria')
          .map((user) => user.email),
      ['premium@example.com'],
    );
    expect(
      summary
          .filteredUsers(subscriptionStatus: UserSubscriptionStatus.active)
          .map((user) => user.email),
      ['premium@example.com'],
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
      ),
      [
        'Search: reader',
        'Plan: Premium',
        'Country: Ghana',
        'Subscription: Active',
      ],
    );
    expect(userAccessActiveFilterLabels(), isEmpty);
    expect(hasUserAccessFilters(country: 'Ghana'), isTrue);
    expect(
      hasUserAccessFilters(subscriptionStatus: UserSubscriptionStatus.pending),
      isTrue,
    );
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

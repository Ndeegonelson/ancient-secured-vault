import 'package:ancient_secure_docs/services/user_access_repository.dart';
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
    ];

    final summary = UserAccessSummary.fromUsers(users);

    expect(summary.totalCount, 3);
    expect(summary.adminCount, 1);
    expect(summary.premiumCount, 1);
    expect(summary.freeCount, 1);
    expect(summary.hasUsers, isTrue);
    expect(summary.users.map((user) => user.email), [
      'admin@example.com',
      'premium@example.com',
      'free@example.com',
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
    expect(summary.filteredUsers(query: 'missing'), isEmpty);
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

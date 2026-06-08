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
      'role': 'reader',
      'subscriptionStatus': 'active',
      'accessLevel': 'premium',
    }, email: ' Ama@Example.com ');

    expect(user.email, 'ama@example.com');
    expect(user.displayName, 'Ama Reader');
    expect(user.access.planLabel, 'Premium');
    expect(user.matches('ama'), isTrue);
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
}

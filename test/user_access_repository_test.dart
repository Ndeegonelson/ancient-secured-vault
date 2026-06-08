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
}

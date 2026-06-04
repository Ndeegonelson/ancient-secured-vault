import 'package:ancient_secure_docs/services/reader_narration_access_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('free users receive bilingual narration with assigned voices', () {
    final policy = ReaderNarrationAccessPolicy.fromUserAccess(
      isAdmin: false,
      hasActiveSubscription: false,
    );

    expect(policy.plan, ReaderNarrationPlan.free);
    expect(policy.canChooseVoice, isFalse);
  });

  test('active subscribers receive continuous bilingual narration', () {
    final policy = ReaderNarrationAccessPolicy.fromUserAccess(
      isAdmin: false,
      hasActiveSubscription: true,
    );

    expect(policy.plan, ReaderNarrationPlan.premium);
    expect(policy.canChooseVoice, isTrue);
  });

  test('inactive subscriptions remain on the free narration plan', () {
    final policy = ReaderNarrationAccessPolicy.fromUserAccess(
      isAdmin: false,
      hasActiveSubscription: false,
    );

    expect(policy.canChooseVoice, isFalse);
    expect(policy.summary, 'Free narration | Assigned bilingual voices');
  });

  test('admins receive full narration access', () {
    final policy = ReaderNarrationAccessPolicy.fromUserAccess(
      isAdmin: true,
      hasActiveSubscription: false,
    );

    expect(policy.plan, ReaderNarrationPlan.admin);
    expect(policy.canChooseVoice, isTrue);
  });
}

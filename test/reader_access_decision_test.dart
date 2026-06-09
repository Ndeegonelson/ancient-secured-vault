import 'package:ancient_secure_docs/services/reader_access_decision.dart';
import 'package:ancient_secure_docs/services/user_access_state.dart';
import 'package:ancient_secure_docs/services/user_device_authorization_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'allows free documents for anonymous readers without device enforcement',
    () {
      final decision = ReaderAccessDecision.evaluate(
        userAccess: const UserAccessState(),
        documentAccessLevel: 'free',
      );

      expect(decision.allowed, isTrue);
      expect(decision.reason, ReaderAccessDecisionReason.allowed);
      expect(decision.documentAccessLevel, 'free');
      expect(decision.userAccessLevel, 'free');
      expect(decision.deviceStatusKey, 'not_checked');
      expect(decision.deviceAuthorizationEnforced, isFalse);
      expect(decision.blockedMessage, isEmpty);
    },
  );

  test('blocks protected documents when subscription access is missing', () {
    final decision = ReaderAccessDecision.evaluate(
      userAccess: const UserAccessState(),
      documentAccessLevel: 'Premium',
      deviceStatus: UserDeviceStatus.trusted,
    );

    expect(decision.allowed, isFalse);
    expect(decision.reason, ReaderAccessDecisionReason.subscriptionRequired);
    expect(decision.reasonKey, 'subscription_required');
    expect(decision.blockedMessage, 'Subscription required to open this PDF.');
    expect(decision.toLogDetails(), {
      'accessDecisionReason': 'subscription_required',
      'deviceAuthorizationStatus': 'trusted',
      'deviceAuthorizationEnforced': false,
    });
  });

  test(
    'monitors blocked devices without enforcing device authorization yet',
    () {
      final decision = ReaderAccessDecision.evaluate(
        userAccess: const UserAccessState(
          hasActiveSubscription: true,
          accessLevel: 'premium',
        ),
        documentAccessLevel: 'premium',
        deviceStatus: UserDeviceStatus.blocked,
      );

      expect(decision.allowed, isTrue);
      expect(decision.reason, ReaderAccessDecisionReason.allowed);
      expect(decision.deviceStatusKey, 'blocked');
      expect(decision.deviceAuthorizationEnforced, isFalse);
    },
  );

  test('can enforce trusted devices when the security gate is enabled', () {
    final premiumAccess = const UserAccessState(
      hasActiveSubscription: true,
      accessLevel: 'premium',
    );

    final pending = ReaderAccessDecision.evaluate(
      userAccess: premiumAccess,
      documentAccessLevel: 'premium',
      deviceStatus: UserDeviceStatus.pending,
      enforceDeviceAuthorization: true,
    );
    final blocked = ReaderAccessDecision.evaluate(
      userAccess: premiumAccess,
      documentAccessLevel: 'premium',
      deviceStatus: UserDeviceStatus.blocked,
      enforceDeviceAuthorization: true,
    );
    final trusted = ReaderAccessDecision.evaluate(
      userAccess: premiumAccess,
      documentAccessLevel: 'premium',
      deviceStatus: UserDeviceStatus.trusted,
      enforceDeviceAuthorization: true,
    );

    expect(pending.allowed, isFalse);
    expect(pending.reason, ReaderAccessDecisionReason.devicePending);
    expect(
      pending.blockedMessage,
      'This device needs admin approval before opening protected PDFs.',
    );
    expect(blocked.allowed, isFalse);
    expect(blocked.reason, ReaderAccessDecisionReason.deviceBlocked);
    expect(
      blocked.blockedMessage,
      'This device is blocked from opening protected PDFs.',
    );
    expect(trusted.allowed, isTrue);
    expect(trusted.reason, ReaderAccessDecisionReason.allowed);
    expect(trusted.deviceAuthorizationEnforced, isTrue);
  });
}

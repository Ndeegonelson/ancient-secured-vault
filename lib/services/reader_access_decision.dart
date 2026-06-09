import 'user_access_state.dart';
import 'user_device_authorization_repository.dart';

enum ReaderAccessDecisionReason {
  allowed,
  subscriptionRequired,
  devicePending,
  deviceBlocked,
}

class ReaderAccessDecision {
  const ReaderAccessDecision({
    required this.allowed,
    required this.reason,
    required this.documentAccessLevel,
    required this.userAccessLevel,
    required this.deviceStatusKey,
    required this.deviceAuthorizationEnforced,
  });

  factory ReaderAccessDecision.evaluate({
    required UserAccessState userAccess,
    required String documentAccessLevel,
    UserDeviceStatus? deviceStatus,
    bool enforceDeviceAuthorization = false,
  }) {
    final normalizedDocumentAccessLevel = documentAccessLevel
        .trim()
        .toLowerCase();
    final subscriptionAllowed = userAccess.canOpenPdfWithAccessLevel(
      normalizedDocumentAccessLevel,
    );
    final deviceStatusKey = deviceStatus == null
        ? 'not_checked'
        : userDeviceStatusKey(deviceStatus);

    if (!subscriptionAllowed) {
      return ReaderAccessDecision(
        allowed: false,
        reason: ReaderAccessDecisionReason.subscriptionRequired,
        documentAccessLevel: normalizedDocumentAccessLevel.isEmpty
            ? 'free'
            : normalizedDocumentAccessLevel,
        userAccessLevel: userAccess.accessLevel,
        deviceStatusKey: deviceStatusKey,
        deviceAuthorizationEnforced: enforceDeviceAuthorization,
      );
    }

    if (enforceDeviceAuthorization) {
      if (deviceStatus == UserDeviceStatus.blocked) {
        return ReaderAccessDecision(
          allowed: false,
          reason: ReaderAccessDecisionReason.deviceBlocked,
          documentAccessLevel: normalizedDocumentAccessLevel.isEmpty
              ? 'free'
              : normalizedDocumentAccessLevel,
          userAccessLevel: userAccess.accessLevel,
          deviceStatusKey: deviceStatusKey,
          deviceAuthorizationEnforced: true,
        );
      }

      if (deviceStatus != UserDeviceStatus.trusted) {
        return ReaderAccessDecision(
          allowed: false,
          reason: ReaderAccessDecisionReason.devicePending,
          documentAccessLevel: normalizedDocumentAccessLevel.isEmpty
              ? 'free'
              : normalizedDocumentAccessLevel,
          userAccessLevel: userAccess.accessLevel,
          deviceStatusKey: deviceStatusKey,
          deviceAuthorizationEnforced: true,
        );
      }
    }

    return ReaderAccessDecision(
      allowed: true,
      reason: ReaderAccessDecisionReason.allowed,
      documentAccessLevel: normalizedDocumentAccessLevel.isEmpty
          ? 'free'
          : normalizedDocumentAccessLevel,
      userAccessLevel: userAccess.accessLevel,
      deviceStatusKey: deviceStatusKey,
      deviceAuthorizationEnforced: enforceDeviceAuthorization,
    );
  }

  final bool allowed;
  final ReaderAccessDecisionReason reason;
  final String documentAccessLevel;
  final String userAccessLevel;
  final String deviceStatusKey;
  final bool deviceAuthorizationEnforced;

  String get reasonKey {
    return switch (reason) {
      ReaderAccessDecisionReason.allowed => 'allowed',
      ReaderAccessDecisionReason.subscriptionRequired =>
        'subscription_required',
      ReaderAccessDecisionReason.devicePending => 'device_pending',
      ReaderAccessDecisionReason.deviceBlocked => 'device_blocked',
    };
  }

  String get blockedMessage {
    return switch (reason) {
      ReaderAccessDecisionReason.allowed => '',
      ReaderAccessDecisionReason.subscriptionRequired =>
        'Subscription required to open this PDF.',
      ReaderAccessDecisionReason.devicePending =>
        'This device needs admin approval before opening protected PDFs.',
      ReaderAccessDecisionReason.deviceBlocked =>
        'This device is blocked from opening protected PDFs.',
    };
  }

  Map<String, dynamic> toLogDetails() {
    return {
      'accessDecisionReason': reasonKey,
      'deviceAuthorizationStatus': deviceStatusKey,
      'deviceAuthorizationEnforced': deviceAuthorizationEnforced,
    };
  }
}

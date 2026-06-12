enum UserSubscriptionStatus {
  none,
  trial,
  active,
  pending,
  inactive,
  expired,
  cancelled,
}

class UserAccessState {
  const UserAccessState({
    this.isAdmin = false,
    this.hasActiveSubscription = false,
    this.accessLevel = 'free',
    this.subscriptionStatus = UserSubscriptionStatus.none,
    this.subscriptionExpiresAt,
  });

  factory UserAccessState.fromFirestore(Map<String, dynamic>? data) {
    final accessLevel = _readAccessLevel(data?['accessLevel']);
    final subscriptionStatus = readUserSubscriptionStatus(
      data?['subscriptionStatus'],
    );
    final subscriptionExpiresAt = _readDateTime(
      data?['subscriptionExpiresAt'] ??
          data?['subscriptionEndsAt'] ??
          data?['subscriptionEndDate'],
    );
    final hasActiveSubscription = _hasActiveSubscription(
      accessLevel: accessLevel,
      subscriptionStatus: subscriptionStatus,
      subscriptionExpiresAt: subscriptionExpiresAt,
    );

    return UserAccessState(
      isAdmin: data?['role'] == 'admin',
      hasActiveSubscription: hasActiveSubscription,
      accessLevel: accessLevel,
      subscriptionStatus: subscriptionStatus,
      subscriptionExpiresAt: subscriptionExpiresAt,
    );
  }

  final bool isAdmin;
  final bool hasActiveSubscription;
  final String accessLevel;
  final UserSubscriptionStatus subscriptionStatus;
  final DateTime? subscriptionExpiresAt;

  bool get canAccessMainVault => isAdmin || hasActiveSubscription;

  bool get canManageVault => isAdmin;

  bool get hasSubscriptionExpiry => subscriptionExpiresAt != null;

  bool get isSubscriptionExpired {
    final expiresAt = subscriptionExpiresAt;
    return expiresAt != null && !expiresAt.isAfter(DateTime.now());
  }

  int get priority {
    if (isAdmin) return 3;
    if (hasActiveSubscription) return 2;
    return 1;
  }

  String get planLabel {
    if (isAdmin) return 'Admin';
    if (hasActiveSubscription) return 'Premium';
    return 'Free';
  }

  String get subscriptionStatusLabel {
    return userSubscriptionStatusLabel(subscriptionStatus);
  }

  bool canOpenPdfWithAccessLevel(String documentAccessLevel) {
    final normalizedAccessLevel = documentAccessLevel.trim().toLowerCase();

    if (normalizedAccessLevel == 'premium') {
      return canAccessMainVault;
    }

    return true;
  }

  static bool _hasActiveSubscription({
    required String accessLevel,
    required UserSubscriptionStatus subscriptionStatus,
    required DateTime? subscriptionExpiresAt,
  }) {
    final hasExpired =
        subscriptionExpiresAt != null &&
        !subscriptionExpiresAt.isAfter(DateTime.now());

    if (hasExpired) return false;

    return switch (subscriptionStatus) {
      UserSubscriptionStatus.active || UserSubscriptionStatus.trial => true,
      UserSubscriptionStatus.none => accessLevel == 'premium',
      UserSubscriptionStatus.pending ||
      UserSubscriptionStatus.inactive ||
      UserSubscriptionStatus.expired ||
      UserSubscriptionStatus.cancelled => false,
    };
  }

  static String _readAccessLevel(dynamic value) {
    final accessLevel = value?.toString().trim().toLowerCase() ?? '';
    return accessLevel.isEmpty ? 'free' : accessLevel;
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    try {
      final date = (value as dynamic).toDate();
      if (date is DateTime) return date;
    } catch (_) {
      // Firestore timestamps expose toDate; strings and test values do not.
    }

    return DateTime.tryParse(value.toString());
  }
}

UserSubscriptionStatus readUserSubscriptionStatus(dynamic value) {
  return switch (value?.toString().trim().toLowerCase()) {
    'trial' || 'trialing' => UserSubscriptionStatus.trial,
    'active' => UserSubscriptionStatus.active,
    'pending' ||
    'pending_payment' ||
    'payment_pending' => UserSubscriptionStatus.pending,
    'inactive' => UserSubscriptionStatus.inactive,
    'expired' || 'past_due' => UserSubscriptionStatus.expired,
    'cancelled' || 'canceled' => UserSubscriptionStatus.cancelled,
    _ => UserSubscriptionStatus.none,
  };
}

String userSubscriptionStatusKey(UserSubscriptionStatus status) {
  return switch (status) {
    UserSubscriptionStatus.none => 'none',
    UserSubscriptionStatus.trial => 'trial',
    UserSubscriptionStatus.active => 'active',
    UserSubscriptionStatus.pending => 'pending',
    UserSubscriptionStatus.inactive => 'inactive',
    UserSubscriptionStatus.expired => 'expired',
    UserSubscriptionStatus.cancelled => 'cancelled',
  };
}

String userSubscriptionStatusLabel(UserSubscriptionStatus status) {
  return switch (status) {
    UserSubscriptionStatus.none => 'Not set',
    UserSubscriptionStatus.trial => 'Trial',
    UserSubscriptionStatus.active => 'Active',
    UserSubscriptionStatus.pending => 'Pending',
    UserSubscriptionStatus.inactive => 'Inactive',
    UserSubscriptionStatus.expired => 'Expired',
    UserSubscriptionStatus.cancelled => 'Cancelled',
  };
}

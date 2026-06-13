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
    this.subscriptionProvider = '',
    this.stripeSubscriptionStatus = '',
    this.stripeLastPaymentStatus = '',
    this.stripeCustomerId = '',
    this.stripeSubscriptionId = '',
    this.paystackCustomerId = '',
    this.paystackReference = '',
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
      subscriptionProvider: _readText(data?['subscriptionProvider']),
      stripeSubscriptionStatus: _readText(data?['stripeSubscriptionStatus']),
      stripeLastPaymentStatus: _readText(data?['stripeLastPaymentStatus']),
      stripeCustomerId: _readIdentifier(data?['stripeCustomerId']),
      stripeSubscriptionId: _readIdentifier(data?['stripeSubscriptionId']),
      paystackCustomerId: _readIdentifier(data?['paystackCustomerId']),
      paystackReference: _readIdentifier(data?['paystackReference']),
      subscriptionExpiresAt: subscriptionExpiresAt,
    );
  }

  final bool isAdmin;
  final bool hasActiveSubscription;
  final String accessLevel;
  final UserSubscriptionStatus subscriptionStatus;
  final String subscriptionProvider;
  final String stripeSubscriptionStatus;
  final String stripeLastPaymentStatus;
  final String stripeCustomerId;
  final String stripeSubscriptionId;
  final String paystackCustomerId;
  final String paystackReference;
  final DateTime? subscriptionExpiresAt;

  bool get canAccessMainVault => isAdmin || hasActiveSubscription;

  bool get canManageVault => isAdmin;

  bool get canManageStripeBilling => subscriptionProvider == 'stripe';

  String get subscriptionProviderLabel {
    return switch (subscriptionProvider) {
      'stripe' => 'Stripe',
      'paystack' => 'Paystack',
      'ancient_coin' || 'ancient-coin' || 'ancientcoin' => 'Ancient Coin',
      'admin' => 'Admin',
      '' => '',
      _ => subscriptionProvider,
    };
  }

  String get subscriptionReference {
    for (final value in [
      paystackReference,
      stripeSubscriptionId,
      stripeCustomerId,
    ]) {
      if (value.trim().isNotEmpty) return value.trim();
    }

    return '';
  }

  String get subscriptionReferenceLabel {
    final reference = subscriptionReference;
    if (reference.isEmpty) return '';

    return switch (subscriptionProvider) {
      'paystack' => 'Paystack ref: $reference',
      'stripe' =>
        stripeSubscriptionId.isNotEmpty
            ? 'Stripe sub: $reference'
            : 'Stripe customer: $reference',
      _ => 'Payment ref: $reference',
    };
  }

  bool get hasStripePaymentIssue {
    if (subscriptionProvider != 'stripe') return false;

    return stripeLastPaymentStatus == 'failed' ||
        stripeSubscriptionStatus == 'past_due' ||
        stripeSubscriptionStatus == 'unpaid' ||
        stripeSubscriptionStatus == 'incomplete';
  }

  String? get stripeAttentionLabel {
    if (subscriptionProvider != 'stripe') return null;

    if (stripeLastPaymentStatus == 'failed') {
      return 'Stripe payment needs attention';
    }

    return switch (stripeSubscriptionStatus) {
      'past_due' => 'Stripe payment is past due',
      'unpaid' => 'Stripe subscription is unpaid',
      'incomplete' => 'Stripe checkout is incomplete',
      'canceled' || 'cancelled' => 'Stripe subscription cancelled',
      _ => null,
    };
  }

  bool get hasSubscriptionExpiry => subscriptionExpiresAt != null;

  bool get isSubscriptionExpired {
    final expiresAt = subscriptionExpiresAt;
    return expiresAt != null && !expiresAt.isAfter(DateTime.now());
  }

  bool get isSubscriptionExpiringSoon {
    final expiresAt = subscriptionExpiresAt;
    if (expiresAt == null || isSubscriptionExpired) return false;

    return expiresAt.difference(DateTime.now()) <= const Duration(days: 7);
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

  static String _readText(dynamic value) {
    return value?.toString().trim().toLowerCase() ?? '';
  }

  static String _readIdentifier(dynamic value) {
    return value?.toString().trim() ?? '';
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

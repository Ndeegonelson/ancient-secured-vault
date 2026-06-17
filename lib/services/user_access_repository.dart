import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_access_state.dart';

enum UserAccessPlan { free, premium, admin }

const int userAccessDefaultDisplayLimit = 20;

abstract interface class UserAccessStore {
  Future<UserAccessState> loadForEmail(String? email);

  Future<List<UserAccessRecord>> listUsers({int limit = 100});

  Future<UserAccessSummary> loadSummary({int limit = 100});

  Future<void> saveAccessPlan({
    required String email,
    required UserAccessPlan plan,
    String? changedByEmail,
    UserAccessPlan? previousPlan,
    String? displayName,
    String? country,
  });

  Future<void> saveSubscriptionStatus({
    required String email,
    required UserSubscriptionStatus status,
    String? changedByEmail,
    UserSubscriptionStatus? previousStatus,
  });

  Future<void> saveSubscriptionExpiry({
    required String email,
    DateTime? expiresAt,
    bool clearExpiry = false,
    String? changedByEmail,
    DateTime? previousExpiresAt,
  });
}

class UserAccessPlanUpdate {
  const UserAccessPlanUpdate({
    required this.role,
    required this.subscriptionStatus,
    required this.accessLevel,
  });

  factory UserAccessPlanUpdate.fromPlan(UserAccessPlan plan) {
    return switch (plan) {
      UserAccessPlan.admin => const UserAccessPlanUpdate(
        role: 'admin',
        subscriptionStatus: 'active',
        accessLevel: 'admin',
      ),
      UserAccessPlan.premium => const UserAccessPlanUpdate(
        role: 'reader',
        subscriptionStatus: 'active',
        accessLevel: 'premium',
      ),
      UserAccessPlan.free => const UserAccessPlanUpdate(
        role: 'reader',
        subscriptionStatus: 'inactive',
        accessLevel: 'free',
      ),
    };
  }

  final String role;
  final String subscriptionStatus;
  final String accessLevel;

  Map<String, dynamic> toFirestore({Object? updatedAt}) {
    return {
      'role': role,
      'subscriptionStatus': subscriptionStatus,
      'accessLevel': accessLevel,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }
}

class UserAccessChangeDraft {
  const UserAccessChangeDraft({
    required this.targetEmail,
    required this.changedByEmail,
    required this.previousPlan,
    required this.nextPlan,
  });

  final String targetEmail;
  final String changedByEmail;
  final UserAccessPlan? previousPlan;
  final UserAccessPlan nextPlan;

  Map<String, dynamic> toMap({required Object createdAt}) {
    return {
      'targetEmail': emailDocumentId(targetEmail),
      'changedByEmail': emailDocumentId(changedByEmail),
      'previousPlan': previousPlan == null
          ? null
          : userAccessPlanKey(previousPlan!),
      'nextPlan': userAccessPlanKey(nextPlan),
      'createdAt': createdAt,
    };
  }
}

class UserAccessChangeRecord {
  const UserAccessChangeRecord({
    required this.id,
    required this.targetEmail,
    required this.changedByEmail,
    required this.previousPlan,
    required this.nextPlan,
    this.createdAt,
  });

  factory UserAccessChangeRecord.fromMap(
    Map<String, dynamic> data, {
    required String id,
  }) {
    return UserAccessChangeRecord(
      id: id,
      targetEmail: emailDocumentId(data['targetEmail']?.toString()),
      changedByEmail: emailDocumentId(data['changedByEmail']?.toString()),
      previousPlan: readUserAccessPlan(data['previousPlan']),
      nextPlan: readUserAccessPlan(data['nextPlan']) ?? UserAccessPlan.free,
      createdAt: data['createdAt'],
    );
  }

  final String id;
  final String targetEmail;
  final String changedByEmail;
  final UserAccessPlan? previousPlan;
  final UserAccessPlan nextPlan;
  final dynamic createdAt;
}

class UserSubscriptionStatusUpdate {
  const UserSubscriptionStatusUpdate({required this.status});

  final UserSubscriptionStatus status;

  Map<String, dynamic> toFirestore({Object? updatedAt}) {
    return {
      'subscriptionStatus': userSubscriptionStatusKey(status),
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }
}

class UserSubscriptionExpiryUpdate {
  const UserSubscriptionExpiryUpdate({this.expiresAt, this.clearExpiry = false})
    : assert(expiresAt != null || clearExpiry);

  final DateTime? expiresAt;
  final bool clearExpiry;

  Map<String, dynamic> toFirestore({Object? updatedAt, Object? deleteValue}) {
    return {
      'subscriptionExpiresAt': clearExpiry ? deleteValue : expiresAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }
}

class UserSubscriptionStatusChangeDraft {
  const UserSubscriptionStatusChangeDraft({
    required this.targetEmail,
    required this.changedByEmail,
    required this.previousStatus,
    required this.nextStatus,
  });

  final String targetEmail;
  final String changedByEmail;
  final UserSubscriptionStatus? previousStatus;
  final UserSubscriptionStatus nextStatus;

  Map<String, dynamic> toMap({required Object createdAt}) {
    return {
      'targetEmail': emailDocumentId(targetEmail),
      'changedByEmail': emailDocumentId(changedByEmail),
      'previousSubscriptionStatus': previousStatus == null
          ? null
          : userSubscriptionStatusKey(previousStatus!),
      'nextSubscriptionStatus': userSubscriptionStatusKey(nextStatus),
      'createdAt': createdAt,
    };
  }
}

class UserSubscriptionExpiryChangeDraft {
  const UserSubscriptionExpiryChangeDraft({
    required this.targetEmail,
    required this.changedByEmail,
    required this.previousExpiresAt,
    required this.nextExpiresAt,
    required this.clearExpiry,
  });

  final String targetEmail;
  final String changedByEmail;
  final DateTime? previousExpiresAt;
  final DateTime? nextExpiresAt;
  final bool clearExpiry;

  Map<String, dynamic> toMap({required Object createdAt}) {
    return {
      'targetEmail': emailDocumentId(targetEmail),
      'changedByEmail': emailDocumentId(changedByEmail),
      'subscriptionChangeType': 'expiry',
      'previousSubscriptionExpiresAt': previousExpiresAt?.toIso8601String(),
      'nextSubscriptionExpiresAt': clearExpiry
          ? null
          : nextExpiresAt?.toIso8601String(),
      'createdAt': createdAt,
    };
  }
}

class UserSubscriptionStatusChangeRecord {
  const UserSubscriptionStatusChangeRecord({
    required this.id,
    required this.targetEmail,
    required this.changedByEmail,
    required this.previousStatus,
    required this.nextStatus,
    required this.changeType,
    this.previousExpiresAt,
    this.nextExpiresAt,
    this.createdAt,
  });

  factory UserSubscriptionStatusChangeRecord.fromMap(
    Map<String, dynamic> data, {
    required String id,
  }) {
    return UserSubscriptionStatusChangeRecord(
      id: id,
      targetEmail: emailDocumentId(data['targetEmail']?.toString()),
      changedByEmail: emailDocumentId(data['changedByEmail']?.toString()),
      previousStatus: _readOptionalSubscriptionStatus(
        data['previousSubscriptionStatus'],
      ),
      nextStatus: readUserSubscriptionStatus(data['nextSubscriptionStatus']),
      changeType:
          data['subscriptionChangeType']?.toString().trim().toLowerCase() ??
          'status',
      previousExpiresAt: _readDateTime(data['previousSubscriptionExpiresAt']),
      nextExpiresAt: _readDateTime(data['nextSubscriptionExpiresAt']),
      createdAt: data['createdAt'],
    );
  }

  final String id;
  final String targetEmail;
  final String changedByEmail;
  final UserSubscriptionStatus? previousStatus;
  final UserSubscriptionStatus nextStatus;
  final String changeType;
  final DateTime? previousExpiresAt;
  final DateTime? nextExpiresAt;
  final dynamic createdAt;

  bool get isExpiryChange =>
      changeType == 'expiry' ||
      previousExpiresAt != null ||
      nextExpiresAt != null;

  static UserSubscriptionStatus? _readOptionalSubscriptionStatus(
    dynamic value,
  ) {
    if (value == null) return null;

    return readUserSubscriptionStatus(value);
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

class UserAccessRecord {
  const UserAccessRecord({
    required this.email,
    required this.access,
    this.displayName = '',
    this.country = '',
    this.createdAt,
    this.updatedAt,
  });

  factory UserAccessRecord.fromMap(
    Map<String, dynamic> data, {
    required String email,
  }) {
    return UserAccessRecord(
      email: emailDocumentId(email),
      displayName: data['displayName']?.toString() ?? '',
      country: _readText(
        data['country'] ?? data['countryName'] ?? data['countryCode'],
      ),
      access: UserAccessState.fromFirestore(data),
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
    );
  }

  final String email;
  final String displayName;
  final String country;
  final UserAccessState access;
  final dynamic createdAt;
  final dynamic updatedAt;

  bool matches(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;

    return email.contains(normalizedQuery) ||
        displayName.toLowerCase().contains(normalizedQuery) ||
        country.toLowerCase().contains(normalizedQuery) ||
        access.planLabel.toLowerCase().contains(normalizedQuery) ||
        access.subscriptionStatusLabel.toLowerCase().contains(
          normalizedQuery,
        ) ||
        access.accessLevel.contains(normalizedQuery);
  }

  static List<UserAccessRecord> sortForAdminList(
    Iterable<UserAccessRecord> users,
  ) {
    final sorted = List<UserAccessRecord>.from(users);
    sorted.sort((a, b) {
      final planComparison = b.access.priority.compareTo(a.access.priority);
      if (planComparison != 0) return planComparison;

      return a.email.compareTo(b.email);
    });

    return sorted;
  }

  static String _readText(dynamic value) {
    return value?.toString().trim() ?? '';
  }
}

class UserAccessSummary {
  const UserAccessSummary({
    required this.users,
    required this.adminCount,
    required this.premiumCount,
    required this.freeCount,
    this.trialCount = 0,
    this.pendingCount = 0,
    this.expiredCount = 0,
    this.cancelledCount = 0,
    this.expiredByDateCount = 0,
    this.expiringSoonCount = 0,
    this.missingRenewalDateCount = 0,
    this.recentChanges = const [],
    this.recentSubscriptionChanges = const [],
  });

  factory UserAccessSummary.fromUsers(
    Iterable<UserAccessRecord> users, {
    List<UserAccessChangeRecord> recentChanges = const [],
    List<UserSubscriptionStatusChangeRecord> recentSubscriptionChanges =
        const [],
  }) {
    final sortedUsers = UserAccessRecord.sortForAdminList(users);
    var adminCount = 0;
    var premiumCount = 0;
    var freeCount = 0;
    var trialCount = 0;
    var pendingCount = 0;
    var expiredCount = 0;
    var cancelledCount = 0;
    var expiredByDateCount = 0;
    var expiringSoonCount = 0;
    var missingRenewalDateCount = 0;

    for (final user in sortedUsers) {
      if (user.access.isAdmin) {
        adminCount++;
      } else if (user.access.hasActiveSubscription) {
        premiumCount++;
      } else {
        freeCount++;
      }

      switch (user.access.subscriptionStatus) {
        case UserSubscriptionStatus.trial:
          trialCount++;
        case UserSubscriptionStatus.pending:
          pendingCount++;
        case UserSubscriptionStatus.expired:
          expiredCount++;
        case UserSubscriptionStatus.cancelled:
          cancelledCount++;
        case UserSubscriptionStatus.none:
        case UserSubscriptionStatus.active:
        case UserSubscriptionStatus.inactive:
          break;
      }

      if (user.access.isSubscriptionExpired) {
        expiredByDateCount++;
      } else if (user.access.isSubscriptionExpiringSoon) {
        expiringSoonCount++;
      }
      if (user.access.needsAdminRenewalDate) {
        missingRenewalDateCount++;
      }
    }

    return UserAccessSummary(
      users: List.unmodifiable(sortedUsers),
      adminCount: adminCount,
      premiumCount: premiumCount,
      freeCount: freeCount,
      trialCount: trialCount,
      pendingCount: pendingCount,
      expiredCount: expiredCount,
      cancelledCount: cancelledCount,
      expiredByDateCount: expiredByDateCount,
      expiringSoonCount: expiringSoonCount,
      missingRenewalDateCount: missingRenewalDateCount,
      recentChanges: List.unmodifiable(recentChanges),
      recentSubscriptionChanges: List.unmodifiable(recentSubscriptionChanges),
    );
  }

  final List<UserAccessRecord> users;
  final int adminCount;
  final int premiumCount;
  final int freeCount;
  final int trialCount;
  final int pendingCount;
  final int expiredCount;
  final int cancelledCount;
  final int expiredByDateCount;
  final int expiringSoonCount;
  final int missingRenewalDateCount;
  final List<UserAccessChangeRecord> recentChanges;
  final List<UserSubscriptionStatusChangeRecord> recentSubscriptionChanges;

  int get totalCount => users.length;
  bool get hasUsers => users.isNotEmpty;
  bool get hasRecentChanges => recentChanges.isNotEmpty;
  bool get hasRecentSubscriptionChanges => recentSubscriptionChanges.isNotEmpty;
  bool get hasSubscriptionAttention =>
      pendingCount > 0 ||
      expiredCount > 0 ||
      cancelledCount > 0 ||
      expiredByDateCount > 0 ||
      expiringSoonCount > 0 ||
      missingRenewalDateCount > 0;
  int get subscriptionReviewCount =>
      pendingCount +
      expiredCount +
      cancelledCount +
      expiredByDateCount +
      expiringSoonCount +
      missingRenewalDateCount;
  List<UserAccessRecord> get missingRenewalDateUsers => List.unmodifiable(
    users.where((user) => user.access.needsAdminRenewalDate),
  );
  List<String> get countryOptions {
    final countries = users
        .map((user) => user.country.trim())
        .where((country) => country.isNotEmpty)
        .toSet()
        .toList();
    countries.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return List.unmodifiable(countries);
  }

  List<UserAccessRecord> filteredUsers({
    String query = '',
    UserAccessPlan? plan,
    String country = '',
    UserSubscriptionStatus? subscriptionStatus,
    bool subscriptionReviewOnly = false,
  }) {
    final normalizedCountry = country.trim().toLowerCase();

    return List.unmodifiable(
      users.where((user) {
        final matchesPlan =
            plan == null || userAccessPlanForState(user.access) == plan;
        final matchesCountry =
            normalizedCountry.isEmpty ||
            user.country.trim().toLowerCase() == normalizedCountry;
        final matchesSubscription =
            subscriptionStatus == null ||
            user.access.subscriptionStatus == subscriptionStatus;
        final matchesSubscriptionReview =
            !subscriptionReviewOnly || userAccessNeedsSubscriptionReview(user);
        return matchesPlan &&
            matchesCountry &&
            matchesSubscription &&
            matchesSubscriptionReview &&
            user.matches(query);
      }),
    );
  }
}

bool userAccessNeedsSubscriptionReview(UserAccessRecord user) {
  return user.access.isSubscriptionExpired ||
      user.access.isSubscriptionExpiringSoon ||
      user.access.needsAdminRenewalDate ||
      user.access.subscriptionStatus == UserSubscriptionStatus.pending ||
      user.access.subscriptionStatus == UserSubscriptionStatus.expired ||
      user.access.subscriptionStatus == UserSubscriptionStatus.cancelled;
}

List<String> userAccessActiveFilterLabels({
  String query = '',
  UserAccessPlan? plan,
  String country = '',
  UserSubscriptionStatus? subscriptionStatus,
  bool subscriptionReviewOnly = false,
}) {
  final labels = <String>[];
  final cleanQuery = query.trim();
  final cleanCountry = country.trim();

  if (cleanQuery.isNotEmpty) {
    labels.add('Search: $cleanQuery');
  }
  if (plan != null) {
    labels.add('Plan: ${userAccessPlanLabel(plan)}');
  }
  if (cleanCountry.isNotEmpty) {
    labels.add('Country: $cleanCountry');
  }
  if (subscriptionStatus != null) {
    labels.add(
      'Subscription: ${userSubscriptionStatusLabel(subscriptionStatus)}',
    );
  }
  if (subscriptionReviewOnly) {
    labels.add('Needs subscription review');
  }

  return List.unmodifiable(labels);
}

bool hasUserAccessFilters({
  String query = '',
  UserAccessPlan? plan,
  String country = '',
  UserSubscriptionStatus? subscriptionStatus,
  bool subscriptionReviewOnly = false,
}) {
  return userAccessActiveFilterLabels(
    query: query,
    plan: plan,
    country: country,
    subscriptionStatus: subscriptionStatus,
    subscriptionReviewOnly: subscriptionReviewOnly,
  ).isNotEmpty;
}

String userAccessFilteredCountLabel({
  required int visibleCount,
  required int totalCount,
  bool hasActiveFilter = false,
}) {
  final safeVisibleCount = visibleCount < 0 ? 0 : visibleCount;
  final safeTotalCount = totalCount < 0 ? 0 : totalCount;
  if (!hasActiveFilter || safeVisibleCount == safeTotalCount) {
    return safeVisibleCount.toString();
  }

  return '$safeVisibleCount of $safeTotalCount';
}

List<String> userAccessRecordDetailParts(
  UserAccessRecord user, {
  bool isCurrentUser = false,
}) {
  return List.unmodifiable([
    if (user.displayName.trim().isNotEmpty) user.displayName.trim(),
    if (user.country.trim().isNotEmpty) user.country.trim(),
    user.access.planLabel,
    'Subscription: ${user.access.subscriptionStatusLabel}',
    if (user.access.subscriptionProviderLabel.isNotEmpty)
      'Provider: ${user.access.subscriptionProviderLabel}',
    if (userAccessSubscriptionExpiryLabel(user.access) != null)
      userAccessSubscriptionExpiryLabel(user.access)!,
    if (user.access.subscriptionReferenceLabel.isNotEmpty)
      user.access.subscriptionReferenceLabel,
    if (userAccessSubscriptionReviewLabel(user) != null)
      userAccessSubscriptionReviewLabel(user)!,
    user.access.canAccessMainVault ? 'Vault enabled' : 'Free vault only',
    if (isCurrentUser) 'Current admin',
  ]);
}

String userAccessRecordDetailLabel(
  UserAccessRecord user, {
  bool isCurrentUser = false,
  String timestampLabel = '',
}) {
  final parts = [
    ...userAccessRecordDetailParts(user, isCurrentUser: isCurrentUser),
    if (timestampLabel.trim().isNotEmpty) timestampLabel.trim(),
  ];

  return parts.join(' | ');
}

String? userAccessListLimitMessage({
  required int visibleCount,
  int displayLimit = userAccessDefaultDisplayLimit,
}) {
  final safeVisibleCount = visibleCount < 0 ? 0 : visibleCount;
  final safeDisplayLimit = displayLimit < 1 ? 1 : displayLimit;
  if (safeVisibleCount <= safeDisplayLimit) return null;

  final userLabel = safeDisplayLimit == 1 ? 'user' : 'users';
  return 'Showing first $safeDisplayLimit $userLabel. Narrow filters to review the rest.';
}

String? userAccessSubscriptionExpiryLabel(UserAccessState access) {
  final expiresAt = access.subscriptionExpiresAt;
  if (expiresAt == null) return null;

  final dateLabel = _formatUserAccessDate(expiresAt);
  if (access.isSubscriptionExpired) {
    return 'Expired: $dateLabel';
  }
  if (access.isSubscriptionExpiringSoon) {
    return 'Expires soon: $dateLabel';
  }

  return 'Expires: $dateLabel';
}

String? userAccessSubscriptionReviewLabel(UserAccessRecord user) {
  final reasons = userAccessSubscriptionReviewReasons(user);
  if (reasons.isEmpty) return null;

  return 'Review: ${reasons.join(', ')}';
}

List<String> userAccessSubscriptionReviewReasons(UserAccessRecord user) {
  final reasons = <String>[];
  final access = user.access;

  if (access.isSubscriptionExpired) {
    reasons.add('expired by date');
  } else if (access.isSubscriptionExpiringSoon) {
    reasons.add('expiring soon');
  }

  if (access.hasStripePaymentIssue) {
    reasons.add('Stripe payment issue');
  }

  if (access.needsAdminRenewalDate) {
    reasons.add('renewal date missing');
  }

  switch (access.subscriptionStatus) {
    case UserSubscriptionStatus.pending:
      reasons.add('pending payment');
    case UserSubscriptionStatus.expired:
      reasons.add('expired status');
    case UserSubscriptionStatus.cancelled:
      reasons.add('cancelled');
    case UserSubscriptionStatus.none:
    case UserSubscriptionStatus.trial:
    case UserSubscriptionStatus.active:
    case UserSubscriptionStatus.inactive:
      break;
  }

  return List.unmodifiable(reasons);
}

String userAccessSubscriptionChangeLabel(
  UserSubscriptionStatusChangeRecord change,
) {
  if (change.isExpiryChange) {
    final previous = change.previousExpiresAt == null
        ? 'No expiry'
        : _formatUserAccessDate(change.previousExpiresAt!);
    final next = change.nextExpiresAt == null
        ? 'No expiry'
        : _formatUserAccessDate(change.nextExpiresAt!);

    return 'Expiry: $previous to $next';
  }

  final previousStatus = change.previousStatus == null
      ? 'Unknown'
      : userSubscriptionStatusLabel(change.previousStatus!);

  return '$previousStatus to ${userSubscriptionStatusLabel(change.nextStatus)}';
}

String _formatUserAccessDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');

  return '${date.year}-$month-$day $hour:$minute';
}

List<String> userAccessSubscriptionAttentionParts(UserAccessSummary summary) {
  final parts = <String>[];

  if (summary.expiredByDateCount > 0) {
    parts.add('${summary.expiredByDateCount} expired by date');
  }
  if (summary.expiringSoonCount > 0) {
    parts.add('${summary.expiringSoonCount} expiring soon');
  }
  if (summary.missingRenewalDateCount > 0) {
    parts.add('${summary.missingRenewalDateCount} missing renewal date');
  }
  if (summary.pendingCount > 0) {
    parts.add('${summary.pendingCount} pending');
  }
  if (summary.expiredCount > 0) {
    parts.add('${summary.expiredCount} expired');
  }
  if (summary.cancelledCount > 0) {
    parts.add('${summary.cancelledCount} cancelled');
  }

  return List.unmodifiable(parts);
}

String? userAccessSubscriptionAttentionLabel(UserAccessSummary summary) {
  final parts = userAccessSubscriptionAttentionParts(summary);
  if (parts.isEmpty) return null;

  return parts.join(' | ');
}

class UserAccessRepository implements UserAccessStore {
  UserAccessRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<UserAccessState> loadForEmail(String? email) async {
    final documentId = emailDocumentId(email);
    if (documentId.isEmpty) return const UserAccessState();

    final doc = await _firestore.collection('users').doc(documentId).get();
    return UserAccessState.fromFirestore(doc.data());
  }

  @override
  Future<List<UserAccessRecord>> listUsers({int limit = 100}) async {
    final safeLimit = limit < 1 ? 1 : limit;
    final snapshot = await _firestore
        .collection('users')
        .limit(safeLimit)
        .get();

    return UserAccessRecord.sortForAdminList(
      snapshot.docs.map(
        (doc) => UserAccessRecord.fromMap(doc.data(), email: doc.id),
      ),
    );
  }

  @override
  Future<UserAccessSummary> loadSummary({int limit = 100}) async {
    final users = listUsers(limit: limit);
    final recentChanges = listRecentAccessChanges();
    final recentSubscriptionChanges = listRecentSubscriptionChanges();

    return UserAccessSummary.fromUsers(
      await users,
      recentChanges: await recentChanges,
      recentSubscriptionChanges: await recentSubscriptionChanges,
    );
  }

  @override
  Future<void> saveAccessPlan({
    required String email,
    required UserAccessPlan plan,
    String? changedByEmail,
    UserAccessPlan? previousPlan,
    String? displayName,
    String? country,
  }) async {
    final documentId = emailDocumentId(email);
    if (documentId.isEmpty) {
      throw ArgumentError('A user email is required to update access.');
    }

    final userDoc = _firestore.collection('users').doc(documentId);
    final batch = _firestore.batch();

    batch.set(userDoc, {
      'email': documentId,
      ...UserAccessPlanUpdate.fromPlan(
        plan,
      ).toFirestore(updatedAt: FieldValue.serverTimestamp()),
    }, SetOptions(merge: true));

    final normalizedChangedByEmail = emailDocumentId(changedByEmail);
    if (normalizedChangedByEmail.isNotEmpty) {
      final auditDoc = _firestore.collection('user_access_audit_logs').doc();
      batch.set(
        auditDoc,
        UserAccessChangeDraft(
          targetEmail: documentId,
          changedByEmail: normalizedChangedByEmail,
          previousPlan: previousPlan,
          nextPlan: plan,
        ).toMap(createdAt: FieldValue.serverTimestamp()),
      );
    }

    await batch.commit();
  }

  @override
  Future<void> saveSubscriptionStatus({
    required String email,
    required UserSubscriptionStatus status,
    String? changedByEmail,
    UserSubscriptionStatus? previousStatus,
  }) async {
    final documentId = emailDocumentId(email);
    if (documentId.isEmpty) {
      throw ArgumentError('A user email is required to update subscription.');
    }

    final userDoc = _firestore.collection('users').doc(documentId);
    final batch = _firestore.batch();

    batch.set(userDoc, {
      'email': documentId,
      ...UserSubscriptionStatusUpdate(
        status: status,
      ).toFirestore(updatedAt: FieldValue.serverTimestamp()),
    }, SetOptions(merge: true));

    final normalizedChangedByEmail = emailDocumentId(changedByEmail);
    if (normalizedChangedByEmail.isNotEmpty) {
      final auditDoc = _firestore
          .collection('user_subscription_audit_logs')
          .doc();
      batch.set(
        auditDoc,
        UserSubscriptionStatusChangeDraft(
          targetEmail: documentId,
          changedByEmail: normalizedChangedByEmail,
          previousStatus: previousStatus,
          nextStatus: status,
        ).toMap(createdAt: FieldValue.serverTimestamp()),
      );
    }

    await batch.commit();
  }

  @override
  Future<void> saveSubscriptionExpiry({
    required String email,
    DateTime? expiresAt,
    bool clearExpiry = false,
    String? changedByEmail,
    DateTime? previousExpiresAt,
  }) async {
    final documentId = emailDocumentId(email);
    if (documentId.isEmpty) {
      throw ArgumentError('A user email is required to update subscription.');
    }

    final userDoc = _firestore.collection('users').doc(documentId);
    final batch = _firestore.batch();

    batch.set(userDoc, {
      'email': documentId,
      ...UserSubscriptionExpiryUpdate(
        expiresAt: expiresAt,
        clearExpiry: clearExpiry,
      ).toFirestore(
        updatedAt: FieldValue.serverTimestamp(),
        deleteValue: FieldValue.delete(),
      ),
    }, SetOptions(merge: true));

    final normalizedChangedByEmail = emailDocumentId(changedByEmail);
    if (normalizedChangedByEmail.isNotEmpty) {
      final auditDoc = _firestore
          .collection('user_subscription_audit_logs')
          .doc();
      batch.set(
        auditDoc,
        UserSubscriptionExpiryChangeDraft(
          targetEmail: documentId,
          changedByEmail: normalizedChangedByEmail,
          previousExpiresAt: previousExpiresAt,
          nextExpiresAt: expiresAt,
          clearExpiry: clearExpiry,
        ).toMap(createdAt: FieldValue.serverTimestamp()),
      );
    }

    await batch.commit();
  }

  Future<List<UserAccessChangeRecord>> listRecentAccessChanges({
    int limit = 8,
  }) async {
    final safeLimit = limit < 1 ? 1 : limit;
    final snapshot = await _firestore
        .collection('user_access_audit_logs')
        .orderBy('createdAt', descending: true)
        .limit(safeLimit)
        .get();

    return List.unmodifiable(
      snapshot.docs.map(
        (doc) => UserAccessChangeRecord.fromMap(doc.data(), id: doc.id),
      ),
    );
  }

  Future<List<UserSubscriptionStatusChangeRecord>>
  listRecentSubscriptionChanges({int limit = 8}) async {
    final safeLimit = limit < 1 ? 1 : limit;
    final snapshot = await _firestore
        .collection('user_subscription_audit_logs')
        .orderBy('createdAt', descending: true)
        .limit(safeLimit)
        .get();

    return List.unmodifiable(
      snapshot.docs.map(
        (doc) =>
            UserSubscriptionStatusChangeRecord.fromMap(doc.data(), id: doc.id),
      ),
    );
  }

  static String emailDocumentId(String? email) {
    return email?.trim().toLowerCase() ?? '';
  }
}

String emailDocumentId(String? email) {
  return UserAccessRepository.emailDocumentId(email);
}

String userAccessPlanKey(UserAccessPlan plan) {
  return switch (plan) {
    UserAccessPlan.admin => 'admin',
    UserAccessPlan.premium => 'premium',
    UserAccessPlan.free => 'free',
  };
}

String userAccessPlanLabel(UserAccessPlan plan) {
  return switch (plan) {
    UserAccessPlan.admin => 'Admin',
    UserAccessPlan.premium => 'Premium',
    UserAccessPlan.free => 'Free',
  };
}

UserAccessPlan? readUserAccessPlan(dynamic value) {
  return switch (value?.toString().trim().toLowerCase()) {
    'admin' => UserAccessPlan.admin,
    'premium' => UserAccessPlan.premium,
    'free' => UserAccessPlan.free,
    _ => null,
  };
}

UserAccessPlan userAccessPlanForState(UserAccessState access) {
  if (access.isAdmin) return UserAccessPlan.admin;
  if (access.hasActiveSubscription) return UserAccessPlan.premium;
  return UserAccessPlan.free;
}

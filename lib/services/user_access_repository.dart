import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_access_state.dart';

enum UserAccessPlan { free, premium, admin }

abstract interface class UserAccessStore {
  Future<UserAccessState> loadForEmail(String? email);

  Future<List<UserAccessRecord>> listUsers({int limit = 100});

  Future<UserAccessSummary> loadSummary({int limit = 100});

  Future<void> saveAccessPlan({
    required String email,
    required UserAccessPlan plan,
    String? changedByEmail,
    UserAccessPlan? previousPlan,
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
    this.recentChanges = const [],
  });

  factory UserAccessSummary.fromUsers(
    Iterable<UserAccessRecord> users, {
    List<UserAccessChangeRecord> recentChanges = const [],
  }) {
    final sortedUsers = UserAccessRecord.sortForAdminList(users);
    var adminCount = 0;
    var premiumCount = 0;
    var freeCount = 0;

    for (final user in sortedUsers) {
      if (user.access.isAdmin) {
        adminCount++;
      } else if (user.access.hasActiveSubscription) {
        premiumCount++;
      } else {
        freeCount++;
      }
    }

    return UserAccessSummary(
      users: List.unmodifiable(sortedUsers),
      adminCount: adminCount,
      premiumCount: premiumCount,
      freeCount: freeCount,
      recentChanges: List.unmodifiable(recentChanges),
    );
  }

  final List<UserAccessRecord> users;
  final int adminCount;
  final int premiumCount;
  final int freeCount;
  final List<UserAccessChangeRecord> recentChanges;

  int get totalCount => users.length;
  bool get hasUsers => users.isNotEmpty;
  bool get hasRecentChanges => recentChanges.isNotEmpty;
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
  }) {
    final normalizedCountry = country.trim().toLowerCase();

    return List.unmodifiable(
      users.where((user) {
        final matchesPlan =
            plan == null || userAccessPlanForState(user.access) == plan;
        final matchesCountry =
            normalizedCountry.isEmpty ||
            user.country.trim().toLowerCase() == normalizedCountry;
        return matchesPlan && matchesCountry && user.matches(query);
      }),
    );
  }
}

List<String> userAccessActiveFilterLabels({
  String query = '',
  UserAccessPlan? plan,
  String country = '',
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

  return List.unmodifiable(labels);
}

bool hasUserAccessFilters({
  String query = '',
  UserAccessPlan? plan,
  String country = '',
}) {
  return userAccessActiveFilterLabels(
    query: query,
    plan: plan,
    country: country,
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

    return UserAccessSummary.fromUsers(
      await users,
      recentChanges: await recentChanges,
    );
  }

  @override
  Future<void> saveAccessPlan({
    required String email,
    required UserAccessPlan plan,
    String? changedByEmail,
    UserAccessPlan? previousPlan,
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

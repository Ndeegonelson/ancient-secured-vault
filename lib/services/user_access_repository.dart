import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_access_state.dart';

abstract interface class UserAccessStore {
  Future<UserAccessState> loadForEmail(String? email);

  Future<List<UserAccessRecord>> listUsers({int limit = 100});

  Future<UserAccessSummary> loadSummary({int limit = 100});
}

class UserAccessRecord {
  const UserAccessRecord({
    required this.email,
    required this.access,
    this.displayName = '',
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
      access: UserAccessState.fromFirestore(data),
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
    );
  }

  final String email;
  final String displayName;
  final UserAccessState access;
  final dynamic createdAt;
  final dynamic updatedAt;

  bool matches(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;

    return email.contains(normalizedQuery) ||
        displayName.toLowerCase().contains(normalizedQuery) ||
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
}

class UserAccessSummary {
  const UserAccessSummary({
    required this.users,
    required this.adminCount,
    required this.premiumCount,
    required this.freeCount,
  });

  factory UserAccessSummary.fromUsers(Iterable<UserAccessRecord> users) {
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
    );
  }

  final List<UserAccessRecord> users;
  final int adminCount;
  final int premiumCount;
  final int freeCount;

  int get totalCount => users.length;
  bool get hasUsers => users.isNotEmpty;
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
    return UserAccessSummary.fromUsers(await listUsers(limit: limit));
  }

  static String emailDocumentId(String? email) {
    return email?.trim().toLowerCase() ?? '';
  }
}

String emailDocumentId(String? email) {
  return UserAccessRepository.emailDocumentId(email);
}

import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_access_state.dart';

abstract interface class UserAccessStore {
  Future<UserAccessState> loadForEmail(String? email);
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

  static String emailDocumentId(String? email) {
    return email?.trim().toLowerCase() ?? '';
  }
}

String emailDocumentId(String? email) {
  return UserAccessRepository.emailDocumentId(email);
}

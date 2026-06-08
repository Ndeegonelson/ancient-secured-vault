import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_access_state.dart';

abstract interface class UserAccessStore {
  Future<UserAccessState> loadForEmail(String? email);
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

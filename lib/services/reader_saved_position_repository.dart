import 'package:cloud_firestore/cloud_firestore.dart';

class ReaderSavedPosition {
  const ReaderSavedPosition({
    required this.id,
    required this.userEmail,
    required this.pdfTitle,
    required this.pageNumber,
    this.documentKey = '',
    this.storagePath = '',
    this.createdAt,
  });

  factory ReaderSavedPosition.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return ReaderSavedPosition.fromMap(snapshot.data(), id: snapshot.id);
  }

  factory ReaderSavedPosition.fromMap(
    Map<String, dynamic> data, {
    String id = '',
  }) {
    return ReaderSavedPosition(
      id: id,
      userEmail: data['userEmail']?.toString() ?? '',
      pdfTitle: data['pdfTitle']?.toString() ?? '',
      documentKey: data['documentKey']?.toString() ?? '',
      storagePath: data['storagePath']?.toString() ?? '',
      pageNumber: _readPageNumber(data['pageNumber']),
      createdAt: data['createdAt'],
    );
  }

  final String id;
  final String userEmail;
  final String pdfTitle;
  final String documentKey;
  final String storagePath;
  final int pageNumber;
  final dynamic createdAt;

  bool get hasServerTimestamp => createdAt is Timestamp;

  static List<ReaderSavedPosition> sortNewest(
    Iterable<ReaderSavedPosition> positions,
  ) {
    final sorted = List<ReaderSavedPosition>.from(positions);
    sorted.sort((a, b) {
      final aCreatedAt = a.createdAt;
      final bCreatedAt = b.createdAt;

      if (aCreatedAt is Timestamp && bCreatedAt is Timestamp) {
        return bCreatedAt.compareTo(aCreatedAt);
      }

      if (aCreatedAt is Timestamp) return -1;
      if (bCreatedAt is Timestamp) return 1;

      return 0;
    });

    return sorted;
  }

  static int _readPageNumber(dynamic value) {
    final page = int.tryParse(value.toString()) ?? 1;
    return page < 1 ? 1 : page;
  }
}

class ReaderSavedPositionDraft {
  const ReaderSavedPositionDraft({
    required this.userEmail,
    required this.pdfTitle,
    required this.pageNumber,
    this.documentKey = '',
    this.storagePath = '',
  });

  final String userEmail;
  final String pdfTitle;
  final String documentKey;
  final String storagePath;
  final int pageNumber;
}

abstract interface class ReaderSavedPositionStore {
  Stream<List<ReaderSavedPosition>> watchForDocument({
    required String userEmail,
    required String pdfTitle,
  });

  Future<List<ReaderSavedPosition>> listForDocument({
    required String userEmail,
    required String pdfTitle,
  });

  Future<List<ReaderSavedPosition>> listForUser({
    required String userEmail,
    int limit = 20,
  });

  Future<ReaderSavedPosition?> loadLatest({
    required String userEmail,
    required String pdfTitle,
  });

  Future<void> save(ReaderSavedPositionDraft position);

  Future<void> delete(String positionId);
}

class ReaderSavedPositionRepository implements ReaderSavedPositionStore {
  ReaderSavedPositionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<ReaderSavedPosition>> watchForDocument({
    required String userEmail,
    required String pdfTitle,
  }) {
    return _queryForDocument(
      userEmail: userEmail,
      pdfTitle: pdfTitle,
    ).snapshots().map(
      (snapshot) => ReaderSavedPosition.sortNewest(
        snapshot.docs.map(ReaderSavedPosition.fromSnapshot),
      ),
    );
  }

  @override
  Future<List<ReaderSavedPosition>> listForDocument({
    required String userEmail,
    required String pdfTitle,
  }) async {
    final snapshot = await _queryForDocument(
      userEmail: userEmail,
      pdfTitle: pdfTitle,
    ).get();

    return ReaderSavedPosition.sortNewest(
      snapshot.docs.map(ReaderSavedPosition.fromSnapshot),
    );
  }

  @override
  Future<List<ReaderSavedPosition>> listForUser({
    required String userEmail,
    int limit = 20,
  }) async {
    final snapshot = await _collection
        .where('userEmail', isEqualTo: userEmail)
        .limit(limit < 1 ? 1 : limit)
        .get();

    return ReaderSavedPosition.sortNewest(
      snapshot.docs.map(ReaderSavedPosition.fromSnapshot),
    );
  }

  @override
  Future<ReaderSavedPosition?> loadLatest({
    required String userEmail,
    required String pdfTitle,
  }) async {
    final positions = await listForDocument(
      userEmail: userEmail,
      pdfTitle: pdfTitle,
    );

    return positions.isEmpty ? null : positions.first;
  }

  @override
  Future<void> save(ReaderSavedPositionDraft position) async {
    await _collection.add({
      'userEmail': position.userEmail,
      'pdfTitle': position.pdfTitle,
      'documentKey': position.documentKey,
      'storagePath': position.storagePath,
      'pageNumber': position.pageNumber,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> delete(String positionId) {
    return _collection.doc(positionId).delete();
  }

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('reading_positions');

  Query<Map<String, dynamic>> _queryForDocument({
    required String userEmail,
    required String pdfTitle,
  }) {
    return _collection
        .where('userEmail', isEqualTo: userEmail)
        .where('pdfTitle', isEqualTo: pdfTitle);
  }
}

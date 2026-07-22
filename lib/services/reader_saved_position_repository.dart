import 'dart:convert';

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
    this.updatedAt,
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
      updatedAt: data['updatedAt'],
    );
  }

  final String id;
  final String userEmail;
  final String pdfTitle;
  final String documentKey;
  final String storagePath;
  final int pageNumber;
  final dynamic createdAt;
  final dynamic updatedAt;

  dynamic get latestTimestamp => updatedAt is Timestamp ? updatedAt : createdAt;

  bool get hasServerTimestamp => latestTimestamp is Timestamp;

  static List<ReaderSavedPosition> sortNewest(
    Iterable<ReaderSavedPosition> positions,
  ) {
    final sorted = List<ReaderSavedPosition>.from(positions);
    sorted.sort((a, b) {
      final aCreatedAt = a.latestTimestamp;
      final bCreatedAt = b.latestTimestamp;

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

class ReaderSavedPositionResumePolicy {
  const ReaderSavedPositionResumePolicy._();

  static bool shouldApplySavedPosition({
    required int initialPage,
    required String initialSearchQuery,
    required String openSource,
  }) {
    if (initialPage > 0) return false;
    if (initialSearchQuery.trim().isNotEmpty) return false;

    final normalizedOpenSource = openSource.trim().toLowerCase();
    if (normalizedOpenSource.contains('search')) return false;

    return true;
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

String readerLatestPositionDocumentId(ReaderSavedPositionDraft position) {
  final documentIdentity =
      [position.documentKey, position.storagePath, position.pdfTitle]
          .map((value) => value.trim())
          .firstWhere(
            (value) => value.isNotEmpty,
            orElse: () => 'untitled-document',
          );
  final identity =
      '${position.userEmail.trim().toLowerCase()}|'
      '${documentIdentity.toLowerCase()}';
  return 'latest_${base64Url.encode(utf8.encode(identity)).replaceAll('=', '')}';
}

Map<String, dynamic> readerSavedPositionData(
  ReaderSavedPositionDraft position, {
  Object? createdAt,
  Object? updatedAt,
}) {
  return {
    'userEmail': position.userEmail.trim(),
    'pdfTitle': position.pdfTitle.trim(),
    'documentKey': position.documentKey.trim(),
    'storagePath': position.storagePath.trim(),
    'pageNumber': position.pageNumber < 1 ? 1 : position.pageNumber,
    'createdAt': ?createdAt,
    'updatedAt': ?updatedAt,
  };
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
    String documentKey = '',
  });

  Future<void> save(ReaderSavedPositionDraft position);

  Future<void> saveLatest(ReaderSavedPositionDraft position);

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
    String documentKey = '',
  }) async {
    final cleanDocumentKey = documentKey.trim();
    if (cleanDocumentKey.isNotEmpty) {
      final keyedSnapshot = await _collection
          .where('userEmail', isEqualTo: userEmail)
          .where('documentKey', isEqualTo: cleanDocumentKey)
          .get();
      final keyedPositions = ReaderSavedPosition.sortNewest(
        keyedSnapshot.docs.map(ReaderSavedPosition.fromSnapshot),
      );
      if (keyedPositions.isNotEmpty) return keyedPositions.first;
    }

    final positions = await listForDocument(
      userEmail: userEmail,
      pdfTitle: pdfTitle,
    );

    return positions.isEmpty ? null : positions.first;
  }

  @override
  Future<void> save(ReaderSavedPositionDraft position) async {
    await _collection.add(
      readerSavedPositionData(
        position,
        createdAt: FieldValue.serverTimestamp(),
      ),
    );
  }

  @override
  Future<void> saveLatest(ReaderSavedPositionDraft position) {
    return _collection
        .doc(readerLatestPositionDocumentId(position))
        .set(
          readerSavedPositionData(
            position,
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          ),
          SetOptions(merge: true),
        );
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

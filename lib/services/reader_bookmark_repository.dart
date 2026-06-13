import 'package:cloud_firestore/cloud_firestore.dart';

class ReaderBookmark {
  const ReaderBookmark({
    required this.id,
    required this.userEmail,
    required this.pdfTitle,
    required this.pageNumber,
    this.label = '',
    this.documentKey = '',
    this.storagePath = '',
    this.createdAt,
    this.updatedAt,
  });

  factory ReaderBookmark.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return ReaderBookmark.fromMap(snapshot.data(), id: snapshot.id);
  }

  factory ReaderBookmark.fromMap(Map<String, dynamic> data, {String id = ''}) {
    return ReaderBookmark(
      id: id,
      userEmail: data['userEmail']?.toString() ?? '',
      pdfTitle: data['pdfTitle']?.toString() ?? '',
      label: data['label']?.toString() ?? '',
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
  final String label;
  final String documentKey;
  final String storagePath;
  final int pageNumber;
  final dynamic createdAt;
  final dynamic updatedAt;

  String get displayLabel {
    final trimmedLabel = label.trim();
    return trimmedLabel.isEmpty ? 'Page $pageNumber' : trimmedLabel;
  }

  dynamic get latestTimestamp => updatedAt is Timestamp ? updatedAt : createdAt;

  bool matchesSearch(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;

    final searchableText = [
      displayLabel,
      label,
      'page $pageNumber',
      pageNumber.toString(),
    ].join(' ').toLowerCase();

    return searchableText.contains(normalizedQuery);
  }

  static List<ReaderBookmark> sortNewest(Iterable<ReaderBookmark> bookmarks) {
    final sorted = List<ReaderBookmark>.from(bookmarks);
    sorted.sort((a, b) {
      final aTimestamp = a.latestTimestamp;
      final bTimestamp = b.latestTimestamp;

      if (aTimestamp is Timestamp && bTimestamp is Timestamp) {
        return bTimestamp.compareTo(aTimestamp);
      }

      if (aTimestamp is Timestamp) return -1;
      if (bTimestamp is Timestamp) return 1;

      return 0;
    });

    return sorted;
  }

  static List<ReaderBookmark> search(
    Iterable<ReaderBookmark> bookmarks,
    String query,
  ) {
    return bookmarks
        .where((bookmark) => bookmark.matchesSearch(query))
        .toList();
  }

  static int _readPageNumber(dynamic value) {
    final page = int.tryParse(value.toString()) ?? 1;
    return page < 1 ? 1 : page;
  }
}

class ReaderBookmarkDraft {
  const ReaderBookmarkDraft({
    required this.userEmail,
    required this.pdfTitle,
    required this.pageNumber,
    this.label = '',
    this.documentKey = '',
    this.storagePath = '',
  });

  final String userEmail;
  final String pdfTitle;
  final String label;
  final String documentKey;
  final String storagePath;
  final int pageNumber;
}

abstract interface class ReaderBookmarkStore {
  Stream<List<ReaderBookmark>> watchForDocument({
    required String userEmail,
    required String pdfTitle,
  });

  Future<List<ReaderBookmark>> listForUser({
    required String userEmail,
    int limit = 20,
  });

  Future<void> save(ReaderBookmarkDraft bookmark);

  Future<void> updateLabel({required String bookmarkId, required String label});

  Future<void> delete(String bookmarkId);
}

class ReaderBookmarkRepository implements ReaderBookmarkStore {
  ReaderBookmarkRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<ReaderBookmark>> watchForDocument({
    required String userEmail,
    required String pdfTitle,
  }) {
    return _queryForDocument(
      userEmail: userEmail,
      pdfTitle: pdfTitle,
    ).snapshots().map(
      (snapshot) => ReaderBookmark.sortNewest(
        snapshot.docs.map(ReaderBookmark.fromSnapshot),
      ),
    );
  }

  @override
  Future<List<ReaderBookmark>> listForUser({
    required String userEmail,
    int limit = 20,
  }) async {
    final snapshot = await _collection
        .where('userEmail', isEqualTo: userEmail)
        .limit(limit < 1 ? 1 : limit)
        .get();

    return ReaderBookmark.sortNewest(
      snapshot.docs.map(ReaderBookmark.fromSnapshot),
    );
  }

  @override
  Future<void> save(ReaderBookmarkDraft bookmark) {
    return _collection.add({
      'userEmail': bookmark.userEmail,
      'pdfTitle': bookmark.pdfTitle,
      'label': bookmark.label,
      'documentKey': bookmark.documentKey,
      'storagePath': bookmark.storagePath,
      'pageNumber': bookmark.pageNumber,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateLabel({
    required String bookmarkId,
    required String label,
  }) {
    return _collection.doc(bookmarkId).update({
      'label': label,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> delete(String bookmarkId) {
    return _collection.doc(bookmarkId).delete();
  }

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('reader_bookmarks');

  Query<Map<String, dynamic>> _queryForDocument({
    required String userEmail,
    required String pdfTitle,
  }) {
    return _collection
        .where('userEmail', isEqualTo: userEmail)
        .where('pdfTitle', isEqualTo: pdfTitle);
  }
}

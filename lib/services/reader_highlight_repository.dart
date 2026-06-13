import 'package:cloud_firestore/cloud_firestore.dart';

class ReaderHighlight {
  const ReaderHighlight({
    required this.id,
    required this.userEmail,
    required this.pdfTitle,
    required this.selectedText,
    required this.pageNumber,
    this.color = 'yellow',
    this.note = '',
    this.documentKey = '',
    this.storagePath = '',
    this.createdAt,
    this.updatedAt,
  });

  factory ReaderHighlight.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return ReaderHighlight.fromMap(snapshot.data(), id: snapshot.id);
  }

  factory ReaderHighlight.fromMap(Map<String, dynamic> data, {String id = ''}) {
    return ReaderHighlight(
      id: id,
      userEmail: data['userEmail']?.toString() ?? '',
      pdfTitle: data['pdfTitle']?.toString() ?? '',
      selectedText: data['selectedText']?.toString() ?? '',
      color: _readColor(data['color']),
      note: data['note']?.toString() ?? '',
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
  final String selectedText;
  final String color;
  final String note;
  final String documentKey;
  final String storagePath;
  final int pageNumber;
  final dynamic createdAt;
  final dynamic updatedAt;

  String get displayColor => _displayColor(color);
  bool get hasNote => note.trim().isNotEmpty;
  dynamic get latestTimestamp => updatedAt is Timestamp ? updatedAt : createdAt;

  bool matchesSearch(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;

    final searchableText = [
      selectedText,
      note,
      displayColor,
      color,
      'page $pageNumber',
      pageNumber.toString(),
    ].join(' ').toLowerCase();

    return searchableText.contains(normalizedQuery);
  }

  static List<ReaderHighlight> sortNewest(
    Iterable<ReaderHighlight> highlights,
  ) {
    final sorted = List<ReaderHighlight>.from(highlights);
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

  static List<ReaderHighlight> search(
    Iterable<ReaderHighlight> highlights,
    String query,
  ) {
    return highlights
        .where((highlight) => highlight.matchesSearch(query))
        .toList();
  }

  static int _readPageNumber(dynamic value) {
    final page = int.tryParse(value.toString()) ?? 1;
    return page < 1 ? 1 : page;
  }

  static String _readColor(dynamic value) {
    final color = value?.toString().trim().toLowerCase();
    if (color == null || color.isEmpty) return 'yellow';

    return switch (color) {
      'green' || 'blue' || 'pink' || 'red' => color,
      _ => 'yellow',
    };
  }

  static String _displayColor(String value) {
    final color = _readColor(value);
    return color[0].toUpperCase() + color.substring(1);
  }
}

class ReaderHighlightDraft {
  const ReaderHighlightDraft({
    required this.userEmail,
    required this.pdfTitle,
    required this.selectedText,
    required this.pageNumber,
    this.color = 'yellow',
    this.note = '',
    this.documentKey = '',
    this.storagePath = '',
  });

  final String userEmail;
  final String pdfTitle;
  final String selectedText;
  final String color;
  final String note;
  final String documentKey;
  final String storagePath;
  final int pageNumber;
}

abstract interface class ReaderHighlightStore {
  Stream<List<ReaderHighlight>> watchForDocument({
    required String userEmail,
    required String pdfTitle,
  });

  Future<List<ReaderHighlight>> listForUser({
    required String userEmail,
    int limit = 20,
  });

  Future<void> save(ReaderHighlightDraft highlight);

  Future<void> updateNote({required String highlightId, required String note});

  Future<void> delete(String highlightId);
}

class ReaderHighlightRepository implements ReaderHighlightStore {
  ReaderHighlightRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<ReaderHighlight>> watchForDocument({
    required String userEmail,
    required String pdfTitle,
  }) {
    return _queryForDocument(
      userEmail: userEmail,
      pdfTitle: pdfTitle,
    ).snapshots().map(
      (snapshot) => ReaderHighlight.sortNewest(
        snapshot.docs.map(ReaderHighlight.fromSnapshot),
      ),
    );
  }

  @override
  Future<List<ReaderHighlight>> listForUser({
    required String userEmail,
    int limit = 20,
  }) async {
    final snapshot = await _collection
        .where('userEmail', isEqualTo: userEmail)
        .limit(limit < 1 ? 1 : limit)
        .get();

    return ReaderHighlight.sortNewest(
      snapshot.docs.map(ReaderHighlight.fromSnapshot),
    );
  }

  @override
  Future<void> save(ReaderHighlightDraft highlight) {
    return _collection.add({
      'userEmail': highlight.userEmail,
      'pdfTitle': highlight.pdfTitle,
      'selectedText': highlight.selectedText,
      'color': highlight.color,
      'note': highlight.note,
      'documentKey': highlight.documentKey,
      'storagePath': highlight.storagePath,
      'pageNumber': highlight.pageNumber,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateNote({required String highlightId, required String note}) {
    return _collection.doc(highlightId).update({
      'note': note,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> delete(String highlightId) {
    return _collection.doc(highlightId).delete();
  }

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('reader_highlights');

  Query<Map<String, dynamic>> _queryForDocument({
    required String userEmail,
    required String pdfTitle,
  }) {
    return _collection
        .where('userEmail', isEqualTo: userEmail)
        .where('pdfTitle', isEqualTo: pdfTitle);
  }
}

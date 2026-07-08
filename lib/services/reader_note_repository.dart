import 'package:cloud_firestore/cloud_firestore.dart';

class ReaderNote {
  const ReaderNote({
    required this.id,
    required this.userEmail,
    required this.pdfTitle,
    required this.note,
    required this.pageNumber,
    this.selectedText = '',
    this.color = 'yellow',
    this.documentKey = '',
    this.storagePath = '',
    this.category = '',
    this.createdAt,
    this.updatedAt,
  });

  factory ReaderNote.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return ReaderNote.fromMap(snapshot.data(), id: snapshot.id);
  }

  factory ReaderNote.fromMap(Map<String, dynamic> data, {String id = ''}) {
    return ReaderNote(
      id: id,
      userEmail: data['userEmail']?.toString() ?? '',
      pdfTitle: data['pdfTitle']?.toString() ?? '',
      selectedText: data['selectedText']?.toString() ?? '',
      note: data['note']?.toString() ?? '',
      color: data['color']?.toString() ?? 'yellow',
      documentKey: data['documentKey']?.toString() ?? '',
      storagePath: data['storagePath']?.toString() ?? '',
      category: _readCategory(data['category']),
      pageNumber: _readPageNumber(data['pageNumber']),
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
    );
  }

  final String id;
  final String userEmail;
  final String pdfTitle;
  final String selectedText;
  final String note;
  final String color;
  final String documentKey;
  final String storagePath;
  final String category;
  final int pageNumber;
  final dynamic createdAt;
  final dynamic updatedAt;

  dynamic get latestTimestamp => updatedAt is Timestamp ? updatedAt : createdAt;
  String get displayCategory => _readCategory(category);

  bool matchesSearch(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;

    final searchableText = [
      note,
      selectedText,
      displayCategory,
      color,
      'page $pageNumber',
      pageNumber.toString(),
    ].join(' ').toLowerCase();

    return searchableText.contains(normalizedQuery);
  }

  static List<ReaderNote> sortNewest(Iterable<ReaderNote> notes) {
    final sorted = List<ReaderNote>.from(notes);
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

  static List<ReaderNote> search(Iterable<ReaderNote> notes, String query) {
    return notes.where((note) => note.matchesSearch(query)).toList();
  }

  static int _readPageNumber(dynamic value) {
    final page = int.tryParse(value.toString()) ?? 1;
    return page < 1 ? 1 : page;
  }

  static String _readCategory(dynamic value) {
    final category = value?.toString().trim();
    return category == null || category.isEmpty ? 'General' : category;
  }
}

class ReaderNoteDraft {
  const ReaderNoteDraft({
    required this.userEmail,
    required this.pdfTitle,
    required this.note,
    required this.pageNumber,
    this.selectedText = '',
    this.color = 'yellow',
    this.documentKey = '',
    this.storagePath = '',
    this.category = 'General',
  });

  final String userEmail;
  final String pdfTitle;
  final String selectedText;
  final String note;
  final String color;
  final String documentKey;
  final String storagePath;
  final String category;
  final int pageNumber;
}

Map<String, dynamic> readerNoteSaveData(
  ReaderNoteDraft note, {
  Object? createdAt,
}) {
  final cleanNote = note.note.trim();
  if (cleanNote.isEmpty) {
    throw ArgumentError.value(note.note, 'note', 'Note text cannot be empty.');
  }

  return {
    'userEmail': note.userEmail.trim(),
    'pdfTitle': note.pdfTitle.trim(),
    'selectedText': note.selectedText.trim(),
    'note': cleanNote,
    'color': note.color.trim().isEmpty ? 'yellow' : note.color.trim(),
    'documentKey': note.documentKey.trim(),
    'storagePath': note.storagePath.trim(),
    'category': ReaderNote._readCategory(note.category),
    'pageNumber': ReaderNote._readPageNumber(note.pageNumber),
    'createdAt': createdAt ?? FieldValue.serverTimestamp(),
  };
}

class ReaderNoteDocumentLookup {
  const ReaderNoteDocumentLookup._({required this.field, required this.value});

  factory ReaderNoteDocumentLookup.from({
    String documentKey = '',
    required String pdfTitle,
  }) {
    final cleanDocumentKey = documentKey.trim();
    if (cleanDocumentKey.isNotEmpty) {
      return ReaderNoteDocumentLookup._(
        field: 'documentKey',
        value: cleanDocumentKey,
      );
    }

    return ReaderNoteDocumentLookup._(
      field: 'pdfTitle',
      value: pdfTitle.trim(),
    );
  }

  final String field;
  final String value;

  bool get usesDocumentKey => field == 'documentKey';
}

abstract interface class ReaderNoteStore {
  Stream<List<ReaderNote>> watchForDocument({
    required String userEmail,
    required String pdfTitle,
    String documentKey = '',
  });

  Future<List<ReaderNote>> listForUser({
    required String userEmail,
    int limit = 20,
  });

  Future<void> save(ReaderNoteDraft note);

  Future<void> updateNote({
    required String noteId,
    required String note,
    required String category,
  });

  Future<void> delete(String noteId);
}

class ReaderNoteRepository implements ReaderNoteStore {
  ReaderNoteRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<ReaderNote>> watchForDocument({
    required String userEmail,
    required String pdfTitle,
    String documentKey = '',
  }) {
    return _queryForDocument(
      userEmail: userEmail,
      pdfTitle: pdfTitle,
      documentKey: documentKey,
    ).snapshots().map(
      (snapshot) =>
          ReaderNote.sortNewest(snapshot.docs.map(ReaderNote.fromSnapshot)),
    );
  }

  @override
  Future<List<ReaderNote>> listForUser({
    required String userEmail,
    int limit = 20,
  }) async {
    final snapshot = await _collection
        .where('userEmail', isEqualTo: userEmail)
        .limit(limit < 1 ? 1 : limit)
        .get();

    return ReaderNote.sortNewest(snapshot.docs.map(ReaderNote.fromSnapshot));
  }

  @override
  Future<void> save(ReaderNoteDraft note) {
    return _collection.add(readerNoteSaveData(note));
  }

  @override
  Future<void> updateNote({
    required String noteId,
    required String note,
    required String category,
  }) {
    return _collection.doc(noteId).update({
      'note': note,
      'category': category,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> delete(String noteId) {
    return _collection.doc(noteId).delete();
  }

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('reader_notes');

  Query<Map<String, dynamic>> _queryForDocument({
    required String userEmail,
    required String pdfTitle,
    String documentKey = '',
  }) {
    final lookup = ReaderNoteDocumentLookup.from(
      documentKey: documentKey,
      pdfTitle: pdfTitle,
    );

    return _collection
        .where('userEmail', isEqualTo: userEmail.trim())
        .where(lookup.field, isEqualTo: lookup.value);
  }
}

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
      category: data['category']?.toString() ?? '',
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

  bool matchesSearch(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;

    final searchableText = [
      note,
      selectedText,
      category,
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
    this.category = '',
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

abstract interface class ReaderNoteStore {
  Stream<List<ReaderNote>> watchForDocument({
    required String userEmail,
    required String pdfTitle,
  });

  Future<void> save(ReaderNoteDraft note);

  Future<void> updateNote({required String noteId, required String note});

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
  }) {
    return _queryForDocument(
      userEmail: userEmail,
      pdfTitle: pdfTitle,
    ).snapshots().map(
      (snapshot) =>
          ReaderNote.sortNewest(snapshot.docs.map(ReaderNote.fromSnapshot)),
    );
  }

  @override
  Future<void> save(ReaderNoteDraft note) {
    return _collection.add({
      'userEmail': note.userEmail,
      'pdfTitle': note.pdfTitle,
      'selectedText': note.selectedText,
      'note': note.note,
      'color': note.color,
      'documentKey': note.documentKey,
      'storagePath': note.storagePath,
      'category': note.category,
      'pageNumber': note.pageNumber,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateNote({required String noteId, required String note}) {
    return _collection.doc(noteId).update({
      'note': note,
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
  }) {
    return _collection
        .where('userEmail', isEqualTo: userEmail)
        .where('pdfTitle', isEqualTo: pdfTitle);
  }
}

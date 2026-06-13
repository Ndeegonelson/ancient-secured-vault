import 'package:cloud_firestore/cloud_firestore.dart';

enum ReaderSuggestionStatus { open, reviewing, resolved, archived }

class ReaderSuggestion {
  const ReaderSuggestion({
    required this.id,
    required this.userEmail,
    required this.message,
    this.status = ReaderSuggestionStatus.open,
    this.source = '',
    this.createdAt,
    this.updatedAt,
  });

  factory ReaderSuggestion.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return ReaderSuggestion.fromMap(snapshot.data(), id: snapshot.id);
  }

  factory ReaderSuggestion.fromMap(
    Map<String, dynamic> data, {
    String id = '',
  }) {
    return ReaderSuggestion(
      id: id,
      userEmail: data['userEmail']?.toString().trim() ?? '',
      message: data['message']?.toString().trim() ?? '',
      status: readReaderSuggestionStatus(data['status']),
      source: data['source']?.toString().trim() ?? '',
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
    );
  }

  final String id;
  final String userEmail;
  final String message;
  final ReaderSuggestionStatus status;
  final String source;
  final dynamic createdAt;
  final dynamic updatedAt;

  dynamic get latestTimestamp => updatedAt is Timestamp ? updatedAt : createdAt;
  bool get hasMessage => message.trim().isNotEmpty;

  static List<ReaderSuggestion> sortNewest(
    Iterable<ReaderSuggestion> suggestions,
  ) {
    final sorted = suggestions.where((item) => item.hasMessage).toList();
    sorted.sort(
      (a, b) => _compareCreatedAt(a.latestTimestamp, b.latestTimestamp),
    );
    return sorted;
  }

  static int _compareCreatedAt(dynamic a, dynamic b) {
    if (a is Timestamp && b is Timestamp) return b.compareTo(a);
    if (a is Timestamp) return -1;
    if (b is Timestamp) return 1;
    return 0;
  }
}

class ReaderSuggestionDraft {
  const ReaderSuggestionDraft({
    required this.userEmail,
    required this.message,
    this.source = 'reader_dashboard',
  });

  final String? userEmail;
  final String message;
  final String source;

  Map<String, dynamic> toFirestore({required Object createdAt}) {
    return {
      'userEmail': userEmail?.trim(),
      'message': message.trim(),
      'source': source.trim().isEmpty ? 'reader_dashboard' : source.trim(),
      'status': readerSuggestionStatusKey(ReaderSuggestionStatus.open),
      'createdAt': createdAt,
    };
  }
}

abstract interface class ReaderSuggestionStore {
  Future<List<ReaderSuggestion>> listRecent({int limit = 30});

  Future<List<ReaderSuggestion>> listForUser({
    required String userEmail,
    int limit = 10,
  });

  Future<void> save(ReaderSuggestionDraft suggestion);

  Future<void> updateStatus({
    required String suggestionId,
    required ReaderSuggestionStatus status,
  });
}

class ReaderSuggestionRepository implements ReaderSuggestionStore {
  ReaderSuggestionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<List<ReaderSuggestion>> listRecent({int limit = 30}) async {
    final snapshot = await _collection.limit(limit < 1 ? 1 : limit).get();
    return ReaderSuggestion.sortNewest(
      snapshot.docs.map(ReaderSuggestion.fromSnapshot),
    );
  }

  @override
  Future<List<ReaderSuggestion>> listForUser({
    required String userEmail,
    int limit = 10,
  }) async {
    final snapshot = await _collection
        .where('userEmail', isEqualTo: userEmail)
        .limit(limit < 1 ? 1 : limit)
        .get();

    return ReaderSuggestion.sortNewest(
      snapshot.docs.map(ReaderSuggestion.fromSnapshot),
    );
  }

  @override
  Future<void> save(ReaderSuggestionDraft suggestion) {
    return _collection.add(
      suggestion.toFirestore(createdAt: FieldValue.serverTimestamp()),
    );
  }

  @override
  Future<void> updateStatus({
    required String suggestionId,
    required ReaderSuggestionStatus status,
  }) {
    return _collection.doc(suggestionId).update({
      'status': readerSuggestionStatusKey(status),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('reader_suggestions');
}

ReaderSuggestionStatus readReaderSuggestionStatus(dynamic value) {
  return switch (value?.toString().trim().toLowerCase()) {
    'reviewing' || 'in_review' => ReaderSuggestionStatus.reviewing,
    'resolved' || 'done' => ReaderSuggestionStatus.resolved,
    'archived' || 'hidden' => ReaderSuggestionStatus.archived,
    _ => ReaderSuggestionStatus.open,
  };
}

String readerSuggestionStatusKey(ReaderSuggestionStatus status) {
  return switch (status) {
    ReaderSuggestionStatus.open => 'open',
    ReaderSuggestionStatus.reviewing => 'reviewing',
    ReaderSuggestionStatus.resolved => 'resolved',
    ReaderSuggestionStatus.archived => 'archived',
  };
}

String readerSuggestionStatusLabel(ReaderSuggestionStatus status) {
  return switch (status) {
    ReaderSuggestionStatus.open => 'Open',
    ReaderSuggestionStatus.reviewing => 'Reviewing',
    ReaderSuggestionStatus.resolved => 'Resolved',
    ReaderSuggestionStatus.archived => 'Archived',
  };
}

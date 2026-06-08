import 'package:cloud_firestore/cloud_firestore.dart';

class ReaderActivityLogContext {
  const ReaderActivityLogContext({
    required this.userEmail,
    required this.pdfTitle,
    required this.readerSessionId,
    required this.documentAccessLevel,
    required this.openSource,
    this.documentKey = '',
    this.storagePath = '',
  });

  final String? userEmail;
  final String pdfTitle;
  final String readerSessionId;
  final String documentAccessLevel;
  final String openSource;
  final String documentKey;
  final String storagePath;

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'userEmail': userEmail,
      'pdfTitle': pdfTitle,
      'readerSessionId': readerSessionId,
      'documentAccessLevel': documentAccessLevel,
      'openSource': openSource,
    };

    final normalizedDocumentKey = documentKey.trim();
    if (normalizedDocumentKey.isNotEmpty) {
      data['documentKey'] = normalizedDocumentKey;
    }

    final normalizedStoragePath = storagePath.trim();
    if (normalizedStoragePath.isNotEmpty) {
      data['storagePath'] = normalizedStoragePath;
    }

    return data;
  }
}

class ReaderAccessLogDraft {
  const ReaderAccessLogDraft({
    required this.context,
    required this.userAccessLevel,
    required this.initialPage,
    required this.hasInitialSearchQuery,
    required this.isAdmin,
    required this.hasActiveSubscription,
    required this.allowed,
  });

  final ReaderActivityLogContext context;
  final String userAccessLevel;
  final int initialPage;
  final bool hasInitialSearchQuery;
  final bool isAdmin;
  final bool hasActiveSubscription;
  final bool allowed;

  Map<String, dynamic> toMap({required Object createdAt}) {
    return {
      ...context.toMap(),
      'userAccessLevel': userAccessLevel,
      'initialPage': initialPage,
      'hasInitialSearchQuery': hasInitialSearchQuery,
      'isAdmin': isAdmin,
      'hasActiveSubscription': hasActiveSubscription,
      'allowed': allowed,
      'createdAt': createdAt,
    };
  }
}

class ReaderActionLogDraft {
  const ReaderActionLogDraft({
    required this.context,
    required this.action,
    this.details = const {},
  });

  final ReaderActivityLogContext context;
  final String action;
  final Map<String, dynamic> details;

  Map<String, dynamic> toMap({required Object createdAt}) {
    return {
      ...context.toMap(),
      'action': action,
      'details': Map<String, dynamic>.from(details),
      'createdAt': createdAt,
    };
  }
}

class ReaderSessionLogDraft {
  const ReaderSessionLogDraft({
    required this.context,
    required this.event,
    this.details = const {},
  });

  final ReaderActivityLogContext context;
  final String event;
  final Map<String, dynamic> details;

  Map<String, dynamic> toMap({required Object createdAt}) {
    return {
      ...context.toMap(),
      'event': event,
      'details': Map<String, dynamic>.from(details),
      'createdAt': createdAt,
    };
  }
}

abstract interface class ReaderActivityLogStore {
  Future<void> logAccessAttempt(ReaderAccessLogDraft draft);

  Future<void> logAction(ReaderActionLogDraft draft);

  Future<void> logSessionLifecycle(ReaderSessionLogDraft draft);
}

class ReaderActivityRepository implements ReaderActivityLogStore {
  ReaderActivityRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<void> logAccessAttempt(ReaderAccessLogDraft draft) {
    return _firestore
        .collection('reader_access_logs')
        .add(draft.toMap(createdAt: FieldValue.serverTimestamp()));
  }

  @override
  Future<void> logAction(ReaderActionLogDraft draft) {
    return _firestore
        .collection('reader_activity_logs')
        .add(draft.toMap(createdAt: FieldValue.serverTimestamp()));
  }

  @override
  Future<void> logSessionLifecycle(ReaderSessionLogDraft draft) {
    return _firestore
        .collection('reader_session_logs')
        .add(draft.toMap(createdAt: FieldValue.serverTimestamp()));
  }
}

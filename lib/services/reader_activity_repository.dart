import 'package:cloud_firestore/cloud_firestore.dart';

import 'reader_activity_analytics.dart';

class ReaderActivityLogContext {
  const ReaderActivityLogContext({
    required this.userEmail,
    required this.pdfTitle,
    required this.readerSessionId,
    required this.documentAccessLevel,
    required this.openSource,
    this.documentKey = '',
    this.storagePath = '',
    this.deviceId = '',
    this.deviceLabel = '',
    this.devicePlatform = '',
  });

  final String? userEmail;
  final String pdfTitle;
  final String readerSessionId;
  final String documentAccessLevel;
  final String openSource;
  final String documentKey;
  final String storagePath;
  final String deviceId;
  final String deviceLabel;
  final String devicePlatform;

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

    final normalizedDeviceId = deviceId.trim();
    if (normalizedDeviceId.isNotEmpty) {
      data['deviceId'] = normalizedDeviceId;
    }

    final normalizedDeviceLabel = deviceLabel.trim();
    if (normalizedDeviceLabel.isNotEmpty) {
      data['deviceLabel'] = normalizedDeviceLabel;
    }

    final normalizedDevicePlatform = devicePlatform.trim();
    if (normalizedDevicePlatform.isNotEmpty) {
      data['devicePlatform'] = normalizedDevicePlatform;
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
    this.accessDecisionReason = '',
    this.deviceAuthorizationStatus = '',
    this.deviceAuthorizationEnforced = false,
  });

  final ReaderActivityLogContext context;
  final String userAccessLevel;
  final int initialPage;
  final bool hasInitialSearchQuery;
  final bool isAdmin;
  final bool hasActiveSubscription;
  final bool allowed;
  final String accessDecisionReason;
  final String deviceAuthorizationStatus;
  final bool deviceAuthorizationEnforced;

  Map<String, dynamic> toMap({required Object createdAt}) {
    return {
      ...context.toMap(),
      'userAccessLevel': userAccessLevel,
      'initialPage': initialPage,
      'hasInitialSearchQuery': hasInitialSearchQuery,
      'isAdmin': isAdmin,
      'hasActiveSubscription': hasActiveSubscription,
      'allowed': allowed,
      if (accessDecisionReason.trim().isNotEmpty)
        'accessDecisionReason': accessDecisionReason.trim(),
      if (deviceAuthorizationStatus.trim().isNotEmpty)
        'deviceAuthorizationStatus': deviceAuthorizationStatus.trim(),
      'deviceAuthorizationEnforced': deviceAuthorizationEnforced,
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

  Future<ReaderActivitySummary> loadSummary({
    int perCollectionLimit = 50,
    int recentLimit = 8,
    int topDocumentLimit = 5,
  }) async {
    final records = await listRecentRecords(limit: perCollectionLimit);

    return const ReaderActivityAnalytics().summarize(
      records,
      recentLimit: recentLimit,
      topDocumentLimit: topDocumentLimit,
    );
  }

  Future<List<ReaderActivityRecord>> listRecentRecords({int limit = 50}) async {
    final safeLimit = limit < 1 ? 1 : limit;
    final snapshots = await Future.wait([
      _recentQuery('reader_access_logs', safeLimit).get(),
      _recentQuery('reader_activity_logs', safeLimit).get(),
      _recentQuery('reader_session_logs', safeLimit).get(),
    ]);

    final records = <ReaderActivityRecord>[
      ...snapshots[0].docs.map(
        (doc) => ReaderActivityRecord.fromAccessLog(doc.data(), id: doc.id),
      ),
      ...snapshots[1].docs.map(
        (doc) => ReaderActivityRecord.fromActionLog(doc.data(), id: doc.id),
      ),
      ...snapshots[2].docs.map(
        (doc) => ReaderActivityRecord.fromSessionLog(doc.data(), id: doc.id),
      ),
    ];

    return List.unmodifiable(
      const ReaderActivityAnalytics()
          .summarize(records, recentLimit: records.length)
          .recentRecords,
    );
  }

  Query<Map<String, dynamic>> _recentQuery(String collection, int limit) {
    return _firestore
        .collection(collection)
        .orderBy('createdAt', descending: true)
        .limit(limit);
  }
}

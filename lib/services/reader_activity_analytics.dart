import 'package:cloud_firestore/cloud_firestore.dart';

enum ReaderActivityRecordType { access, action, session }

class ReaderActivityRecord {
  const ReaderActivityRecord({
    required this.id,
    required this.type,
    required this.userEmail,
    required this.pdfTitle,
    required this.documentAccessLevel,
    required this.openSource,
    required this.createdAt,
    this.readerSessionId = '',
    this.documentKey = '',
    this.storagePath = '',
    this.action = '',
    this.event = '',
    this.allowed,
    this.details = const {},
  });

  factory ReaderActivityRecord.fromAccessLog(
    Map<String, dynamic> data, {
    String id = '',
  }) {
    return ReaderActivityRecord._fromMap(
      data,
      id: id,
      type: ReaderActivityRecordType.access,
      allowed: data['allowed'] == true,
    );
  }

  factory ReaderActivityRecord.fromActionLog(
    Map<String, dynamic> data, {
    String id = '',
  }) {
    return ReaderActivityRecord._fromMap(
      data,
      id: id,
      type: ReaderActivityRecordType.action,
      action: data['action']?.toString() ?? '',
    );
  }

  factory ReaderActivityRecord.fromSessionLog(
    Map<String, dynamic> data, {
    String id = '',
  }) {
    return ReaderActivityRecord._fromMap(
      data,
      id: id,
      type: ReaderActivityRecordType.session,
      event: data['event']?.toString() ?? '',
    );
  }

  factory ReaderActivityRecord._fromMap(
    Map<String, dynamic> data, {
    required String id,
    required ReaderActivityRecordType type,
    String action = '',
    String event = '',
    bool? allowed,
  }) {
    return ReaderActivityRecord(
      id: id,
      type: type,
      userEmail: data['userEmail']?.toString() ?? '',
      pdfTitle: data['pdfTitle']?.toString() ?? '',
      readerSessionId: data['readerSessionId']?.toString() ?? '',
      documentAccessLevel: data['documentAccessLevel']?.toString() ?? '',
      openSource: data['openSource']?.toString() ?? '',
      documentKey: data['documentKey']?.toString() ?? '',
      storagePath: data['storagePath']?.toString() ?? '',
      action: action,
      event: event,
      allowed: allowed,
      details: _readDetails(data['details']),
      createdAt: data['createdAt'],
    );
  }

  final String id;
  final ReaderActivityRecordType type;
  final String userEmail;
  final String pdfTitle;
  final String readerSessionId;
  final String documentAccessLevel;
  final String openSource;
  final String documentKey;
  final String storagePath;
  final String action;
  final String event;
  final bool? allowed;
  final Map<String, dynamic> details;
  final dynamic createdAt;

  String get documentIdentity {
    final normalizedDocumentKey = documentKey.trim();
    if (normalizedDocumentKey.isNotEmpty) return normalizedDocumentKey;

    return pdfTitle.trim();
  }

  String get activityLabel {
    switch (type) {
      case ReaderActivityRecordType.access:
        return allowed == true ? 'Access allowed' : 'Access blocked';
      case ReaderActivityRecordType.action:
        return action.trim().isEmpty ? 'Reader action' : action;
      case ReaderActivityRecordType.session:
        return event.trim().isEmpty ? 'Reader session' : event;
    }
  }

  bool get isBlockedAccess =>
      type == ReaderActivityRecordType.access && allowed == false;

  static Map<String, dynamic> _readDetails(dynamic value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }
}

class ReaderActivityDocumentMetric {
  const ReaderActivityDocumentMetric({
    required this.documentIdentity,
    required this.pdfTitle,
    required this.eventCount,
  });

  final String documentIdentity;
  final String pdfTitle;
  final int eventCount;
}

class ReaderActivitySummary {
  const ReaderActivitySummary({
    required this.accessAttemptCount,
    required this.allowedAccessCount,
    required this.blockedAccessCount,
    required this.actionCount,
    required this.sessionEventCount,
    required this.uniqueReaderCount,
    required this.uniqueDocumentCount,
    required this.topDocuments,
    required this.recentRecords,
  });

  final int accessAttemptCount;
  final int allowedAccessCount;
  final int blockedAccessCount;
  final int actionCount;
  final int sessionEventCount;
  final int uniqueReaderCount;
  final int uniqueDocumentCount;
  final List<ReaderActivityDocumentMetric> topDocuments;
  final List<ReaderActivityRecord> recentRecords;

  int get totalEventCount =>
      accessAttemptCount + actionCount + sessionEventCount;

  bool get hasActivity => totalEventCount > 0;
}

class ReaderActivityAnalytics {
  const ReaderActivityAnalytics();

  ReaderActivitySummary summarize(
    Iterable<ReaderActivityRecord> records, {
    int recentLimit = 8,
    int topDocumentLimit = 5,
  }) {
    final sortedRecords = _sortNewest(records);
    final readers = <String>{};
    final documentTitles = <String, String>{};
    final documentCounts = <String, int>{};

    var accessAttemptCount = 0;
    var allowedAccessCount = 0;
    var blockedAccessCount = 0;
    var actionCount = 0;
    var sessionEventCount = 0;

    for (final record in sortedRecords) {
      final reader = record.userEmail.trim().toLowerCase();
      if (reader.isNotEmpty) readers.add(reader);

      final documentIdentity = record.documentIdentity;
      if (documentIdentity.isNotEmpty) {
        documentTitles[documentIdentity] = record.pdfTitle;
        documentCounts[documentIdentity] =
            (documentCounts[documentIdentity] ?? 0) + 1;
      }

      switch (record.type) {
        case ReaderActivityRecordType.access:
          accessAttemptCount++;
          if (record.allowed == true) {
            allowedAccessCount++;
          } else {
            blockedAccessCount++;
          }
        case ReaderActivityRecordType.action:
          actionCount++;
        case ReaderActivityRecordType.session:
          sessionEventCount++;
      }
    }

    final topDocuments =
        documentCounts.entries
            .map(
              (entry) => ReaderActivityDocumentMetric(
                documentIdentity: entry.key,
                pdfTitle: documentTitles[entry.key] ?? entry.key,
                eventCount: entry.value,
              ),
            )
            .toList()
          ..sort((a, b) => b.eventCount.compareTo(a.eventCount));

    return ReaderActivitySummary(
      accessAttemptCount: accessAttemptCount,
      allowedAccessCount: allowedAccessCount,
      blockedAccessCount: blockedAccessCount,
      actionCount: actionCount,
      sessionEventCount: sessionEventCount,
      uniqueReaderCount: readers.length,
      uniqueDocumentCount: documentCounts.length,
      topDocuments: List.unmodifiable(topDocuments.take(topDocumentLimit)),
      recentRecords: List.unmodifiable(sortedRecords.take(recentLimit)),
    );
  }

  List<ReaderActivityRecord> _sortNewest(
    Iterable<ReaderActivityRecord> records,
  ) {
    final sortedRecords = List<ReaderActivityRecord>.from(records);
    sortedRecords.sort((a, b) => _compareCreatedAt(a.createdAt, b.createdAt));
    return sortedRecords;
  }

  int _compareCreatedAt(dynamic a, dynamic b) {
    if (a is Timestamp && b is Timestamp) return b.compareTo(a);
    if (a is Timestamp) return -1;
    if (b is Timestamp) return 1;
    return 0;
  }
}

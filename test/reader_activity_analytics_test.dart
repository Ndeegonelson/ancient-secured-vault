import 'package:ancient_secure_docs/services/reader_activity_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ReaderActivityRecord accessRecord({
    required String id,
    required String userEmail,
    required String pdfTitle,
    required bool allowed,
    required int createdAt,
    String documentKey = '',
  }) {
    return ReaderActivityRecord.fromAccessLog({
      'userEmail': userEmail,
      'pdfTitle': pdfTitle,
      'documentKey': documentKey,
      'documentAccessLevel': 'premium',
      'openSource': 'premium_dashboard',
      'allowed': allowed,
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(createdAt),
    }, id: id);
  }

  ReaderActivityRecord actionRecord({
    required String id,
    required String userEmail,
    required String pdfTitle,
    required String action,
    required int createdAt,
    String documentKey = '',
  }) {
    return ReaderActivityRecord.fromActionLog({
      'userEmail': userEmail,
      'pdfTitle': pdfTitle,
      'documentKey': documentKey,
      'documentAccessLevel': 'premium',
      'openSource': 'reader_toolbar',
      'action': action,
      'details': {'pageNumber': 3},
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(createdAt),
    }, id: id);
  }

  ReaderActivityRecord sessionRecord({
    required String id,
    required String userEmail,
    required String pdfTitle,
    required String event,
    required int createdAt,
    String documentKey = '',
  }) {
    return ReaderActivityRecord.fromSessionLog({
      'userEmail': userEmail,
      'pdfTitle': pdfTitle,
      'documentKey': documentKey,
      'documentAccessLevel': 'premium',
      'openSource': 'reader',
      'event': event,
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(createdAt),
    }, id: id);
  }

  test('summarizes reader activity for admin dashboard cards', () {
    final summary = const ReaderActivityAnalytics().summarize([
      accessRecord(
        id: 'allowed',
        userEmail: 'reader@example.com',
        pdfTitle: 'Learning Guide.pdf',
        documentKey: 'vault/learning-guide.pdf',
        allowed: true,
        createdAt: 1000,
      ),
      accessRecord(
        id: 'blocked',
        userEmail: 'guest@example.com',
        pdfTitle: 'Learning Guide.pdf',
        documentKey: 'vault/learning-guide.pdf',
        allowed: false,
        createdAt: 2000,
      ),
      actionRecord(
        id: 'action',
        userEmail: 'reader@example.com',
        pdfTitle: 'Learning Guide.pdf',
        documentKey: 'vault/learning-guide.pdf',
        action: 'open_pdf_page',
        createdAt: 3000,
      ),
      sessionRecord(
        id: 'session',
        userEmail: 'reader@example.com',
        pdfTitle: 'Staff Meeting.pdf',
        event: 'started',
        createdAt: 4000,
      ),
    ]);

    expect(summary.totalEventCount, 4);
    expect(summary.accessAttemptCount, 2);
    expect(summary.allowedAccessCount, 1);
    expect(summary.blockedAccessCount, 1);
    expect(summary.actionCount, 1);
    expect(summary.sessionEventCount, 1);
    expect(summary.uniqueReaderCount, 2);
    expect(summary.uniqueDocumentCount, 2);
    expect(summary.hasActivity, isTrue);
  });

  test('sorts recent activity newest first and respects limits', () {
    final summary = const ReaderActivityAnalytics().summarize([
      actionRecord(
        id: 'older',
        userEmail: 'reader@example.com',
        pdfTitle: 'A.pdf',
        action: 'open_pdf_page',
        createdAt: 1000,
      ),
      actionRecord(
        id: 'newer',
        userEmail: 'reader@example.com',
        pdfTitle: 'B.pdf',
        action: 'add_reader_note',
        createdAt: 2000,
      ),
    ], recentLimit: 1);

    expect(summary.recentRecords.map((record) => record.id), ['newer']);
  });

  test('ranks top documents by combined activity', () {
    final summary = const ReaderActivityAnalytics().summarize([
      actionRecord(
        id: 'guide-1',
        userEmail: 'reader@example.com',
        pdfTitle: 'Learning Guide.pdf',
        documentKey: 'vault/learning-guide.pdf',
        action: 'open_pdf_page',
        createdAt: 1000,
      ),
      sessionRecord(
        id: 'guide-2',
        userEmail: 'reader@example.com',
        pdfTitle: 'Learning Guide.pdf',
        documentKey: 'vault/learning-guide.pdf',
        event: 'started',
        createdAt: 2000,
      ),
      actionRecord(
        id: 'minutes',
        userEmail: 'reader@example.com',
        pdfTitle: 'Staff Meeting.pdf',
        action: 'add_reader_bookmark',
        createdAt: 3000,
      ),
    ]);

    expect(
      summary.topDocuments.first.documentIdentity,
      'vault/learning-guide.pdf',
    );
    expect(summary.topDocuments.first.pdfTitle, 'Learning Guide.pdf');
    expect(summary.topDocuments.first.eventCount, 2);
  });

  test('reads useful labels from raw log records', () {
    final blocked = accessRecord(
      id: 'blocked',
      userEmail: 'guest@example.com',
      pdfTitle: 'Protected.pdf',
      allowed: false,
      createdAt: 1000,
    );
    final action = actionRecord(
      id: 'action',
      userEmail: 'reader@example.com',
      pdfTitle: 'Protected.pdf',
      action: 'save_reading_position',
      createdAt: 1000,
    );

    expect(blocked.activityLabel, 'Access blocked');
    expect(blocked.isBlockedAccess, isTrue);
    expect(action.activityLabel, 'save_reading_position');
    expect(action.details, {'pageNumber': 3});
  });
}

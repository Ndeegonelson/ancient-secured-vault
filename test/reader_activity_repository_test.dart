import 'package:ancient_secure_docs/services/reader_activity_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const context = ReaderActivityLogContext(
    userEmail: 'reader@example.com',
    pdfTitle: 'Protected Guide.pdf',
    readerSessionId: 'session-123',
    documentAccessLevel: 'premium',
    openSource: 'premium_dashboard',
    documentKey: 'vault_pdfs/protected-guide.pdf',
    storagePath: 'vault_pdfs/protected-guide.pdf',
    deviceId: 'device-123',
    deviceLabel: 'Windows browser',
    devicePlatform: 'Win32',
  );

  test('builds reader access log payloads for admin analytics', () {
    final draft = ReaderAccessLogDraft(
      context: context,
      userAccessLevel: 'premium',
      initialPage: 4,
      hasInitialSearchQuery: true,
      isAdmin: false,
      hasActiveSubscription: true,
      allowed: true,
      accessDecisionReason: 'allowed',
      deviceAuthorizationStatus: 'trusted',
      deviceAuthorizationMode: 'enforcing',
      deviceAuthorizationEnforced: true,
    );

    expect(draft.toMap(createdAt: 'now'), {
      'userEmail': 'reader@example.com',
      'pdfTitle': 'Protected Guide.pdf',
      'readerSessionId': 'session-123',
      'documentAccessLevel': 'premium',
      'openSource': 'premium_dashboard',
      'documentKey': 'vault_pdfs/protected-guide.pdf',
      'storagePath': 'vault_pdfs/protected-guide.pdf',
      'deviceId': 'device-123',
      'deviceLabel': 'Windows browser',
      'devicePlatform': 'Win32',
      'userAccessLevel': 'premium',
      'initialPage': 4,
      'hasInitialSearchQuery': true,
      'isAdmin': false,
      'hasActiveSubscription': true,
      'allowed': true,
      'accessDecisionReason': 'allowed',
      'deviceAuthorizationStatus': 'trusted',
      'deviceAuthorizationMode': 'enforcing',
      'deviceAuthorizationEnforced': true,
      'createdAt': 'now',
    });
  });

  test('builds reader action log payloads with copied details', () {
    final details = {'pageNumber': 7, 'source': 'toolbar'};
    final draft = ReaderActionLogDraft(
      context: context,
      action: 'open_pdf_page',
      details: details,
    );

    final payload = draft.toMap(createdAt: 'now');
    details['pageNumber'] = 9;

    expect(payload['action'], 'open_pdf_page');
    expect(payload['details'], {'pageNumber': 7, 'source': 'toolbar'});
    expect(payload['createdAt'], 'now');
  });

  test('builds reader session lifecycle payloads', () {
    final draft = ReaderSessionLogDraft(
      context: context,
      event: 'started',
      details: const {'initialPage': 2},
    );

    expect(draft.toMap(createdAt: 'now'), containsPair('event', 'started'));
    expect(
      draft.toMap(createdAt: 'now'),
      containsPair('details', {'initialPage': 2}),
    );
  });

  test('omits blank document identifiers from payload context', () {
    const context = ReaderActivityLogContext(
      userEmail: null,
      pdfTitle: 'Public Guide.pdf',
      readerSessionId: 'session-456',
      documentAccessLevel: 'free',
      openSource: 'free_dashboard',
    );

    expect(context.toMap().containsKey('documentKey'), isFalse);
    expect(context.toMap().containsKey('storagePath'), isFalse);
    expect(context.toMap()['userEmail'], isNull);
  });
}

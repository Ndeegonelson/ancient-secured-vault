import 'package:ancient_secure_docs/services/user_device_authorization_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads device authorization records with safe defaults', () {
    final device = UserDeviceRecord.fromMap({
      'email': ' Reader@Example.COM ',
      'deviceName': 'Office Laptop',
      'os': 'Windows',
      'countryCode': 'Ghana',
      'lastDocumentTitle': 'Protected Guide.pdf',
      'lastOpenSource': 'premium_dashboard',
      'status': 'approved',
    }, id: ' device-1 ');

    expect(device.id, 'device-1');
    expect(device.email, 'reader@example.com');
    expect(device.deviceLabel, 'Office Laptop');
    expect(device.platform, 'Windows');
    expect(device.country, 'Ghana');
    expect(device.lastDocumentTitle, 'Protected Guide.pdf');
    expect(device.lastOpenSource, 'premium_dashboard');
    expect(device.status, UserDeviceStatus.trusted);
    expect(device.isTrusted, isTrue);
    expect(device.needsReview, isFalse);
    expect(device.matches('office'), isTrue);
    expect(device.matches('protected guide'), isTrue);
    expect(device.matches('premium_dashboard'), isTrue);
    expect(device.matches('trusted'), isTrue);
    expect(device.matches('missing'), isFalse);
  });

  test('status flags override older textual device status values', () {
    expect(
      readUserDeviceStatus('trusted', isBlocked: true),
      UserDeviceStatus.blocked,
    );
    expect(
      readUserDeviceStatus('blocked', isTrusted: true),
      UserDeviceStatus.trusted,
    );
    expect(readUserDeviceStatus('unknown'), UserDeviceStatus.pending);
  });

  test('describes device authorization modes for admin review', () {
    expect(
      userDeviceAuthorizationModeKey(UserDeviceAuthorizationMode.monitoring),
      'monitoring',
    );
    expect(
      userDeviceAuthorizationModeTitle(UserDeviceAuthorizationMode.monitoring),
      'Monitoring mode',
    );
    expect(
      userDeviceAuthorizationModeDescription(
        UserDeviceAuthorizationMode.monitoring,
      ),
      contains('logged for admin review'),
    );
    expect(
      userDeviceAuthorizationIsEnforced(UserDeviceAuthorizationMode.monitoring),
      isFalse,
    );
    expect(
      userDeviceAuthorizationIsEnforced(UserDeviceAuthorizationMode.enforcing),
      isTrue,
    );
  });

  test('sorts pending then blocked then trusted devices for admin review', () {
    final trusted = UserDeviceRecord.fromMap({
      'email': 'trusted@example.com',
      'status': 'trusted',
    }, id: 'trusted-device');
    final blocked = UserDeviceRecord.fromMap({
      'email': 'blocked@example.com',
      'status': 'blocked',
    }, id: 'blocked-device');
    final pending = UserDeviceRecord.fromMap({
      'email': 'pending@example.com',
      'status': 'pending',
    }, id: 'pending-device');

    final sorted = UserDeviceRecord.sortForAdminList([
      trusted,
      blocked,
      pending,
    ]);

    expect(sorted.map((device) => device.id), [
      'pending-device',
      'blocked-device',
      'trusted-device',
    ]);
  });

  test('sorts reader devices by recent use before status fallback', () {
    final oldTrusted = UserDeviceRecord.fromMap({
      'email': 'reader@example.com',
      'status': 'trusted',
      'lastSeenAt': Timestamp.fromDate(DateTime(2026, 6, 1)),
    }, id: 'old-trusted');
    final newPending = UserDeviceRecord.fromMap({
      'email': 'reader@example.com',
      'status': 'pending',
      'lastSeenAt': Timestamp.fromDate(DateTime(2026, 6, 9)),
    }, id: 'new-pending');
    final noTimestampBlocked = UserDeviceRecord.fromMap({
      'email': 'reader@example.com',
      'status': 'blocked',
    }, id: 'blocked');
    final noTimestampTrusted = UserDeviceRecord.fromMap({
      'email': 'reader@example.com',
      'status': 'trusted',
    }, id: 'trusted');

    final sorted = UserDeviceRecord.sortForReaderList([
      noTimestampTrusted,
      oldTrusted,
      noTimestampBlocked,
      newPending,
    ]);

    expect(sorted.map((device) => device.id), [
      'new-pending',
      'old-trusted',
      'blocked',
      'trusted',
    ]);
  });

  test('summarizes and filters device authorization records', () {
    const recentChange = UserDeviceStatusChangeRecord(
      id: 'change-1',
      deviceId: 'tablet',
      changedByEmail: 'admin@example.com',
      previousStatus: UserDeviceStatus.pending,
      nextStatus: UserDeviceStatus.blocked,
      createdAt: 'now',
    );
    final summary = UserDeviceSummary.fromDevices(
      [
        UserDeviceRecord.fromMap({
          'email': 'ama@example.com',
          'deviceLabel': 'Ama Phone',
          'platform': 'Android',
          'country': 'Ghana',
          'status': 'pending',
        }, id: 'phone'),
        UserDeviceRecord.fromMap({
          'email': 'kwame@example.com',
          'deviceLabel': 'Kwame Laptop',
          'platform': 'Windows',
          'country': 'Nigeria',
          'status': 'trusted',
        }, id: 'laptop'),
        UserDeviceRecord.fromMap({
          'email': 'blocked@example.com',
          'deviceLabel': 'Blocked Tablet',
          'platform': 'Android',
          'country': 'Ghana',
          'status': 'blocked',
        }, id: 'tablet'),
      ],
      recentChanges: const [recentChange],
    );

    expect(summary.totalCount, 3);
    expect(summary.pendingCount, 1);
    expect(summary.trustedCount, 1);
    expect(summary.blockedCount, 1);
    expect(summary.hasRecentChanges, isTrue);
    expect(summary.recentChanges, const [recentChange]);
    expect(summary.countryOptions, ['Ghana', 'Nigeria']);
    expect(
      summary
          .filteredDevices(query: 'android', country: 'Ghana')
          .map((device) => device.id),
      ['phone', 'tablet'],
    );
    expect(
      summary
          .filteredDevices(status: UserDeviceStatus.trusted)
          .map((device) => device.id),
      ['laptop'],
    );
  });

  test('describes readiness before device enforcement is enabled', () {
    final emptySummary = UserDeviceSummary.fromDevices(const []);
    final pendingSummary = UserDeviceSummary.fromDevices([
      UserDeviceRecord.fromMap({'status': 'pending'}, id: 'pending-device'),
      UserDeviceRecord.fromMap({'status': 'trusted'}, id: 'trusted-device'),
    ]);
    final readySummary = UserDeviceSummary.fromDevices([
      UserDeviceRecord.fromMap({'status': 'trusted'}, id: 'trusted-device'),
      UserDeviceRecord.fromMap({'status': 'blocked'}, id: 'blocked-device'),
    ]);

    expect(emptySummary.isReadyForEnforcement, isFalse);
    expect(
      userDeviceAuthorizationReadinessTitle(emptySummary),
      'Waiting for device records',
    );
    expect(pendingSummary.isReadyForEnforcement, isFalse);
    expect(
      userDeviceAuthorizationReadinessDescription(pendingSummary),
      '1 pending device should be trusted or blocked before enforcement is enabled.',
    );
    expect(readySummary.isReadyForEnforcement, isTrue);
    expect(
      userDeviceAuthorizationReadinessTitle(readySummary),
      'Ready for enforcement trial',
    );
    expect(
      userDeviceAuthorizationReadinessDescription(readySummary),
      '1 trusted device and 1 blocked device are classified.',
    );
  });

  test('builds active device filter labels and filtered count labels', () {
    expect(
      userDeviceActiveFilterLabels(
        query: ' laptop ',
        status: UserDeviceStatus.blocked,
        country: ' Ghana ',
      ),
      ['Search: laptop', 'Status: Blocked', 'Country: Ghana'],
    );
    expect(userDeviceActiveFilterLabels(), isEmpty);
    expect(hasUserDeviceFilters(status: UserDeviceStatus.pending), isTrue);
    expect(hasUserDeviceFilters(), isFalse);
    expect(
      userDeviceFilteredCountLabel(
        visibleCount: 2,
        totalCount: 7,
        hasActiveFilter: true,
      ),
      '2 of 7',
    );
    expect(
      userDeviceFilteredCountLabel(
        visibleCount: 7,
        totalCount: 7,
        hasActiveFilter: true,
      ),
      '7',
    );
  });

  test('builds compact device record labels for admin review', () {
    final device = UserDeviceRecord.fromMap({
      'email': 'reader@example.com',
      'deviceLabel': 'Reader Laptop',
      'platform': 'Chrome on Windows',
      'country': 'Ghana',
      'lastDocumentTitle': 'Protected Guide.pdf',
      'lastOpenSource': 'premium_dashboard',
      'status': 'blocked',
    }, id: 'device-1');
    final anonymousDevice = UserDeviceRecord.fromMap({}, id: 'device-2');

    expect(userDeviceRecordTitle(device), 'Reader Laptop');
    expect(userDeviceRecordTitle(anonymousDevice), 'device-2');
    expect(
      userDeviceRecordDetailLabel(device, timestampLabel: 'Seen today'),
      'reader@example.com | Chrome on Windows | Ghana | Last: Protected Guide.pdf | Source: premium dashboard | Blocked | Seen today',
    );
    expect(userDeviceRecordDetailParts(anonymousDevice), ['Pending']);
  });

  test('describes when the device list is capped for display', () {
    expect(
      userDeviceListLimitMessage(visibleCount: 30, displayLimit: 20),
      'Showing first 20 devices. Narrow filters to review the rest.',
    );
    expect(
      userDeviceListLimitMessage(visibleCount: 20, displayLimit: 20),
      isNull,
    );
    expect(
      userDeviceListLimitMessage(visibleCount: 2, displayLimit: 0),
      'Showing first 1 device. Narrow filters to review the rest.',
    );
  });

  test('builds Firestore updates and audit payloads for device decisions', () {
    expect(
      UserDeviceStatusUpdate.fromStatus(UserDeviceStatus.trusted).toFirestore(),
      {'status': 'trusted', 'isTrusted': true, 'isBlocked': false},
    );
    expect(
      UserDeviceStatusUpdate.fromStatus(
        UserDeviceStatus.blocked,
      ).toFirestore(updatedAt: 'now'),
      {
        'status': 'blocked',
        'isTrusted': false,
        'isBlocked': true,
        'updatedAt': 'now',
      },
    );

    final draft = UserDeviceStatusChangeDraft(
      deviceId: ' device-1 ',
      changedByEmail: ' Admin@Example.COM ',
      previousStatus: UserDeviceStatus.pending,
      nextStatus: UserDeviceStatus.trusted,
    );

    expect(draft.toMap(createdAt: 'now'), {
      'deviceId': 'device-1',
      'changedByEmail': 'admin@example.com',
      'previousStatus': 'pending',
      'nextStatus': 'trusted',
      'createdAt': 'now',
    });

    final change = UserDeviceStatusChangeRecord.fromMap({
      'deviceId': ' device-1 ',
      'changedByEmail': ' Admin@Example.COM ',
      'previousStatus': 'pending',
      'nextStatus': 'blocked',
      'createdAt': 'later',
    }, id: ' change-1 ');

    expect(change.id, 'change-1');
    expect(change.deviceId, 'device-1');
    expect(change.changedByEmail, 'admin@example.com');
    expect(change.previousStatus, UserDeviceStatus.pending);
    expect(change.nextStatus, UserDeviceStatus.blocked);
    expect(change.createdAt, 'later');
    expect(readUserDeviceStatusOrNull('approved'), UserDeviceStatus.trusted);
    expect(readUserDeviceStatusOrNull('missing'), isNull);
    expect(userDeviceStatusChangeTitle(change), 'device-1');
    expect(
      userDeviceStatusChangeDetailLabel(change, timestampLabel: 'Today'),
      'Pending to Blocked | by admin@example.com | Today',
    );
    expect(
      userDeviceStatusChangeTitle(
        const UserDeviceStatusChangeRecord(
          id: 'empty',
          deviceId: '',
          changedByEmail: '',
          previousStatus: null,
          nextStatus: UserDeviceStatus.pending,
        ),
      ),
      'Unknown device',
    );
  });

  test('builds pending seen-device payloads from reader visits', () {
    final draft = UserDeviceSeenDraft(
      deviceId: ' device-123 ',
      email: ' Reader@Example.COM ',
      deviceLabel: ' Windows browser ',
      platform: ' Win32 ',
      lastDocumentTitle: ' Protected Guide ',
      lastOpenSource: ' premium_dashboard ',
    );

    expect(draft.hasDeviceId, isTrue);
    expect(
      draft.toFirestore(
        createdAt: 'created',
        lastSeenAt: 'seen',
        includePendingStatus: true,
      ),
      {
        'deviceId': 'device-123',
        'email': 'reader@example.com',
        'deviceLabel': 'Windows browser',
        'platform': 'Win32',
        'lastDocumentTitle': 'Protected Guide',
        'lastOpenSource': 'premium_dashboard',
        'createdAt': 'created',
        'status': 'pending',
        'isTrusted': false,
        'isBlocked': false,
        'lastSeenAt': 'seen',
      },
    );
  });

  test(
    'seen-device refresh payloads preserve existing authorization status',
    () {
      final draft = UserDeviceSeenDraft(
        deviceId: 'device-123',
        email: 'reader@example.com',
        deviceLabel: 'Windows browser',
      );

      final payload = draft.toFirestore(
        lastSeenAt: 'seen',
        includePendingStatus: false,
      );

      expect(payload['lastSeenAt'], 'seen');
      expect(payload.containsKey('status'), isFalse);
      expect(payload.containsKey('isTrusted'), isFalse);
      expect(payload.containsKey('isBlocked'), isFalse);
    },
  );
}

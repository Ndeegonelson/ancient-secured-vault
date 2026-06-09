import 'package:ancient_secure_docs/services/user_device_authorization_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads device authorization records with safe defaults', () {
    final device = UserDeviceRecord.fromMap({
      'email': ' Reader@Example.COM ',
      'deviceName': 'Office Laptop',
      'os': 'Windows',
      'countryCode': 'Ghana',
      'status': 'approved',
    }, id: ' device-1 ');

    expect(device.id, 'device-1');
    expect(device.email, 'reader@example.com');
    expect(device.deviceLabel, 'Office Laptop');
    expect(device.platform, 'Windows');
    expect(device.country, 'Ghana');
    expect(device.status, UserDeviceStatus.trusted);
    expect(device.isTrusted, isTrue);
    expect(device.needsReview, isFalse);
    expect(device.matches('office'), isTrue);
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

  test('summarizes and filters device authorization records', () {
    final summary = UserDeviceSummary.fromDevices([
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
    ]);

    expect(summary.totalCount, 3);
    expect(summary.pendingCount, 1);
    expect(summary.trustedCount, 1);
    expect(summary.blockedCount, 1);
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
      'status': 'blocked',
    }, id: 'device-1');
    final anonymousDevice = UserDeviceRecord.fromMap({}, id: 'device-2');

    expect(userDeviceRecordTitle(device), 'Reader Laptop');
    expect(userDeviceRecordTitle(anonymousDevice), 'device-2');
    expect(
      userDeviceRecordDetailLabel(device, timestampLabel: 'Seen today'),
      'reader@example.com | Chrome on Windows | Ghana | Blocked | Seen today',
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
  });
}

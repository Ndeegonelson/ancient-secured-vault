import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_access_repository.dart';

enum UserDeviceStatus { pending, trusted, blocked }

enum UserDeviceAuthorizationMode { monitoring, enforcing }

const int userDeviceDefaultDisplayLimit = 20;

abstract interface class UserDeviceAuthorizationStore {
  Future<List<UserDeviceRecord>> listDevices({int limit = 100});

  Future<UserDeviceSummary> loadSummary({int limit = 100});

  Future<UserDeviceStatus?> recordSeenDevice(UserDeviceSeenDraft draft);

  Future<void> saveDeviceStatus({
    required String deviceId,
    required UserDeviceStatus status,
    String? changedByEmail,
    UserDeviceStatus? previousStatus,
  });
}

class UserDeviceStatusUpdate {
  const UserDeviceStatusUpdate({
    required this.status,
    required this.isTrusted,
    required this.isBlocked,
  });

  factory UserDeviceStatusUpdate.fromStatus(UserDeviceStatus status) {
    return switch (status) {
      UserDeviceStatus.pending => const UserDeviceStatusUpdate(
        status: 'pending',
        isTrusted: false,
        isBlocked: false,
      ),
      UserDeviceStatus.trusted => const UserDeviceStatusUpdate(
        status: 'trusted',
        isTrusted: true,
        isBlocked: false,
      ),
      UserDeviceStatus.blocked => const UserDeviceStatusUpdate(
        status: 'blocked',
        isTrusted: false,
        isBlocked: true,
      ),
    };
  }

  final String status;
  final bool isTrusted;
  final bool isBlocked;

  Map<String, dynamic> toFirestore({Object? updatedAt}) {
    return {
      'status': status,
      'isTrusted': isTrusted,
      'isBlocked': isBlocked,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }
}

class UserDeviceSeenDraft {
  const UserDeviceSeenDraft({
    required this.deviceId,
    this.email,
    this.deviceLabel = '',
    this.platform = '',
    this.lastDocumentTitle = '',
    this.lastOpenSource = '',
  });

  final String deviceId;
  final String? email;
  final String deviceLabel;
  final String platform;
  final String lastDocumentTitle;
  final String lastOpenSource;

  bool get hasDeviceId => deviceId.trim().isNotEmpty;

  Map<String, dynamic> toFirestore({
    required Object lastSeenAt,
    Object? createdAt,
    bool includePendingStatus = false,
  }) {
    final data = <String, dynamic>{
      'deviceId': deviceId.trim(),
      'lastSeenAt': lastSeenAt,
    };

    final normalizedEmail = emailDocumentId(email);
    if (normalizedEmail.isNotEmpty) {
      data['email'] = normalizedEmail;
    }

    final normalizedDeviceLabel = deviceLabel.trim();
    if (normalizedDeviceLabel.isNotEmpty) {
      data['deviceLabel'] = normalizedDeviceLabel;
    }

    final normalizedPlatform = platform.trim();
    if (normalizedPlatform.isNotEmpty) {
      data['platform'] = normalizedPlatform;
    }

    final normalizedLastDocumentTitle = lastDocumentTitle.trim();
    if (normalizedLastDocumentTitle.isNotEmpty) {
      data['lastDocumentTitle'] = normalizedLastDocumentTitle;
    }

    final normalizedLastOpenSource = lastOpenSource.trim();
    if (normalizedLastOpenSource.isNotEmpty) {
      data['lastOpenSource'] = normalizedLastOpenSource;
    }

    if (createdAt != null) {
      data['createdAt'] = createdAt;
    }

    if (includePendingStatus) {
      data.addAll(
        UserDeviceStatusUpdate.fromStatus(
          UserDeviceStatus.pending,
        ).toFirestore(),
      );
    }

    return data;
  }
}

class UserDeviceStatusChangeDraft {
  const UserDeviceStatusChangeDraft({
    required this.deviceId,
    required this.changedByEmail,
    required this.previousStatus,
    required this.nextStatus,
  });

  final String deviceId;
  final String changedByEmail;
  final UserDeviceStatus? previousStatus;
  final UserDeviceStatus nextStatus;

  Map<String, dynamic> toMap({required Object createdAt}) {
    return {
      'deviceId': deviceId.trim(),
      'changedByEmail': emailDocumentId(changedByEmail),
      'previousStatus': previousStatus == null
          ? null
          : userDeviceStatusKey(previousStatus!),
      'nextStatus': userDeviceStatusKey(nextStatus),
      'createdAt': createdAt,
    };
  }
}

class UserDeviceRecord {
  const UserDeviceRecord({
    required this.id,
    required this.email,
    required this.status,
    this.deviceLabel = '',
    this.platform = '',
    this.country = '',
    this.lastDocumentTitle = '',
    this.lastOpenSource = '',
    this.createdAt,
    this.lastSeenAt,
    this.updatedAt,
  });

  factory UserDeviceRecord.fromMap(
    Map<String, dynamic> data, {
    required String id,
  }) {
    return UserDeviceRecord(
      id: id.trim(),
      email: emailDocumentId(data['email']?.toString()),
      deviceLabel: _readText(
        data['deviceLabel'] ?? data['label'] ?? data['deviceName'],
      ),
      platform: _readText(data['platform'] ?? data['os'] ?? data['userAgent']),
      country: _readText(
        data['country'] ?? data['countryName'] ?? data['countryCode'],
      ),
      lastDocumentTitle: _readText(data['lastDocumentTitle']),
      lastOpenSource: _readText(data['lastOpenSource']),
      status: readUserDeviceStatus(
        data['status'],
        isTrusted: data['isTrusted'],
        isBlocked: data['isBlocked'],
      ),
      createdAt: data['createdAt'],
      lastSeenAt: data['lastSeenAt'],
      updatedAt: data['updatedAt'],
    );
  }

  final String id;
  final String email;
  final String deviceLabel;
  final String platform;
  final String country;
  final String lastDocumentTitle;
  final String lastOpenSource;
  final UserDeviceStatus status;
  final dynamic createdAt;
  final dynamic lastSeenAt;
  final dynamic updatedAt;

  bool get isTrusted => status == UserDeviceStatus.trusted;
  bool get isBlocked => status == UserDeviceStatus.blocked;
  bool get needsReview => status == UserDeviceStatus.pending;

  bool matches(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;

    return id.toLowerCase().contains(normalizedQuery) ||
        email.contains(normalizedQuery) ||
        deviceLabel.toLowerCase().contains(normalizedQuery) ||
        platform.toLowerCase().contains(normalizedQuery) ||
        country.toLowerCase().contains(normalizedQuery) ||
        lastDocumentTitle.toLowerCase().contains(normalizedQuery) ||
        lastOpenSource.toLowerCase().contains(normalizedQuery) ||
        userDeviceStatusLabel(status).toLowerCase().contains(normalizedQuery);
  }

  static List<UserDeviceRecord> sortForAdminList(
    Iterable<UserDeviceRecord> devices,
  ) {
    final sorted = List<UserDeviceRecord>.from(devices);
    sorted.sort((a, b) {
      final statusComparison = _statusPriority(
        b.status,
      ).compareTo(_statusPriority(a.status));
      if (statusComparison != 0) return statusComparison;

      final emailComparison = a.email.compareTo(b.email);
      if (emailComparison != 0) return emailComparison;

      return a.id.compareTo(b.id);
    });

    return sorted;
  }

  static int _statusPriority(UserDeviceStatus status) {
    return switch (status) {
      UserDeviceStatus.pending => 3,
      UserDeviceStatus.blocked => 2,
      UserDeviceStatus.trusted => 1,
    };
  }

  static String _readText(dynamic value) {
    return value?.toString().trim() ?? '';
  }
}

class UserDeviceSummary {
  const UserDeviceSummary({
    required this.devices,
    required this.pendingCount,
    required this.trustedCount,
    required this.blockedCount,
  });

  factory UserDeviceSummary.fromDevices(Iterable<UserDeviceRecord> devices) {
    final sortedDevices = UserDeviceRecord.sortForAdminList(devices);
    var pendingCount = 0;
    var trustedCount = 0;
    var blockedCount = 0;

    for (final device in sortedDevices) {
      switch (device.status) {
        case UserDeviceStatus.pending:
          pendingCount++;
        case UserDeviceStatus.trusted:
          trustedCount++;
        case UserDeviceStatus.blocked:
          blockedCount++;
      }
    }

    return UserDeviceSummary(
      devices: List.unmodifiable(sortedDevices),
      pendingCount: pendingCount,
      trustedCount: trustedCount,
      blockedCount: blockedCount,
    );
  }

  final List<UserDeviceRecord> devices;
  final int pendingCount;
  final int trustedCount;
  final int blockedCount;

  int get totalCount => devices.length;
  bool get hasDevices => devices.isNotEmpty;
  List<String> get countryOptions {
    final countries = devices
        .map((device) => device.country.trim())
        .where((country) => country.isNotEmpty)
        .toSet()
        .toList();
    countries.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return List.unmodifiable(countries);
  }

  List<UserDeviceRecord> filteredDevices({
    String query = '',
    UserDeviceStatus? status,
    String country = '',
  }) {
    final normalizedCountry = country.trim().toLowerCase();

    return List.unmodifiable(
      devices.where((device) {
        final matchesStatus = status == null || device.status == status;
        final matchesCountry =
            normalizedCountry.isEmpty ||
            device.country.trim().toLowerCase() == normalizedCountry;
        return matchesStatus && matchesCountry && device.matches(query);
      }),
    );
  }

  bool get isReadyForEnforcement => hasDevices && pendingCount == 0;
}

class UserDeviceAuthorizationRepository
    implements UserDeviceAuthorizationStore {
  UserDeviceAuthorizationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<List<UserDeviceRecord>> listDevices({int limit = 100}) async {
    final safeLimit = limit < 1 ? 1 : limit;
    final snapshot = await _firestore
        .collection('user_device_authorizations')
        .limit(safeLimit)
        .get();

    return UserDeviceRecord.sortForAdminList(
      snapshot.docs.map(
        (doc) => UserDeviceRecord.fromMap(doc.data(), id: doc.id),
      ),
    );
  }

  @override
  Future<UserDeviceSummary> loadSummary({int limit = 100}) async {
    return UserDeviceSummary.fromDevices(await listDevices(limit: limit));
  }

  @override
  Future<UserDeviceStatus?> recordSeenDevice(UserDeviceSeenDraft draft) async {
    if (!draft.hasDeviceId) return null;

    final deviceDoc = _firestore
        .collection('user_device_authorizations')
        .doc(draft.deviceId.trim());
    final existingDevice = await deviceDoc.get();
    final existingStatus = existingDevice.exists
        ? UserDeviceRecord.fromMap(
            existingDevice.data() ?? const {},
            id: existingDevice.id,
          ).status
        : null;

    await deviceDoc.set(
      draft.toFirestore(
        createdAt: existingDevice.exists ? null : FieldValue.serverTimestamp(),
        lastSeenAt: FieldValue.serverTimestamp(),
        includePendingStatus: !existingDevice.exists,
      ),
      SetOptions(merge: true),
    );

    return existingStatus ?? UserDeviceStatus.pending;
  }

  @override
  Future<void> saveDeviceStatus({
    required String deviceId,
    required UserDeviceStatus status,
    String? changedByEmail,
    UserDeviceStatus? previousStatus,
  }) async {
    final documentId = deviceId.trim();
    if (documentId.isEmpty) {
      throw ArgumentError('A device id is required to update authorization.');
    }

    final deviceDoc = _firestore
        .collection('user_device_authorizations')
        .doc(documentId);
    final batch = _firestore.batch();

    batch.set(
      deviceDoc,
      UserDeviceStatusUpdate.fromStatus(
        status,
      ).toFirestore(updatedAt: FieldValue.serverTimestamp()),
      SetOptions(merge: true),
    );

    final normalizedChangedByEmail = emailDocumentId(changedByEmail);
    if (normalizedChangedByEmail.isNotEmpty) {
      final auditDoc = _firestore
          .collection('user_device_authorization_audit_logs')
          .doc();
      batch.set(
        auditDoc,
        UserDeviceStatusChangeDraft(
          deviceId: documentId,
          changedByEmail: normalizedChangedByEmail,
          previousStatus: previousStatus,
          nextStatus: status,
        ).toMap(createdAt: FieldValue.serverTimestamp()),
      );
    }

    await batch.commit();
  }
}

String userDeviceStatusKey(UserDeviceStatus status) {
  return switch (status) {
    UserDeviceStatus.pending => 'pending',
    UserDeviceStatus.trusted => 'trusted',
    UserDeviceStatus.blocked => 'blocked',
  };
}

String userDeviceStatusLabel(UserDeviceStatus status) {
  return switch (status) {
    UserDeviceStatus.pending => 'Pending',
    UserDeviceStatus.trusted => 'Trusted',
    UserDeviceStatus.blocked => 'Blocked',
  };
}

String userDeviceAuthorizationModeKey(UserDeviceAuthorizationMode mode) {
  return switch (mode) {
    UserDeviceAuthorizationMode.monitoring => 'monitoring',
    UserDeviceAuthorizationMode.enforcing => 'enforcing',
  };
}

String userDeviceAuthorizationModeTitle(UserDeviceAuthorizationMode mode) {
  return switch (mode) {
    UserDeviceAuthorizationMode.monitoring => 'Monitoring mode',
    UserDeviceAuthorizationMode.enforcing => 'Enforcement mode',
  };
}

String userDeviceAuthorizationModeDescription(
  UserDeviceAuthorizationMode mode,
) {
  return switch (mode) {
    UserDeviceAuthorizationMode.monitoring =>
      'Devices are logged for admin review, but blocked or pending devices can still open documents.',
    UserDeviceAuthorizationMode.enforcing =>
      'Only trusted devices can open protected documents.',
  };
}

bool userDeviceAuthorizationIsEnforced(UserDeviceAuthorizationMode mode) {
  return mode == UserDeviceAuthorizationMode.enforcing;
}

String userDeviceAuthorizationReadinessTitle(UserDeviceSummary summary) {
  if (!summary.hasDevices) return 'Waiting for device records';
  if (summary.pendingCount > 0) return 'Review pending devices first';
  return 'Ready for enforcement trial';
}

String userDeviceAuthorizationReadinessDescription(UserDeviceSummary summary) {
  if (!summary.hasDevices) {
    return 'Open a document from at least one browser to create the first reviewable device record.';
  }

  if (summary.pendingCount > 0) {
    final deviceLabel = summary.pendingCount == 1 ? 'device' : 'devices';
    return '${summary.pendingCount} pending $deviceLabel should be trusted or blocked before enforcement is enabled.';
  }

  final trustedLabel = summary.trustedCount == 1
      ? 'trusted device'
      : 'trusted devices';
  final blockedLabel = summary.blockedCount == 1
      ? 'blocked device'
      : 'blocked devices';
  return '${summary.trustedCount} $trustedLabel and ${summary.blockedCount} $blockedLabel are classified.';
}

UserDeviceStatus readUserDeviceStatus(
  dynamic value, {
  dynamic isTrusted,
  dynamic isBlocked,
}) {
  if (isBlocked == true) return UserDeviceStatus.blocked;
  if (isTrusted == true) return UserDeviceStatus.trusted;

  return switch (value?.toString().trim().toLowerCase()) {
    'trusted' || 'approved' || 'allowed' => UserDeviceStatus.trusted,
    'blocked' || 'denied' || 'rejected' => UserDeviceStatus.blocked,
    _ => UserDeviceStatus.pending,
  };
}

List<String> userDeviceActiveFilterLabels({
  String query = '',
  UserDeviceStatus? status,
  String country = '',
}) {
  final labels = <String>[];
  final cleanQuery = query.trim();
  final cleanCountry = country.trim();

  if (cleanQuery.isNotEmpty) {
    labels.add('Search: $cleanQuery');
  }
  if (status != null) {
    labels.add('Status: ${userDeviceStatusLabel(status)}');
  }
  if (cleanCountry.isNotEmpty) {
    labels.add('Country: $cleanCountry');
  }

  return List.unmodifiable(labels);
}

bool hasUserDeviceFilters({
  String query = '',
  UserDeviceStatus? status,
  String country = '',
}) {
  return userDeviceActiveFilterLabels(
    query: query,
    status: status,
    country: country,
  ).isNotEmpty;
}

String userDeviceFilteredCountLabel({
  required int visibleCount,
  required int totalCount,
  bool hasActiveFilter = false,
}) {
  final safeVisibleCount = visibleCount < 0 ? 0 : visibleCount;
  final safeTotalCount = totalCount < 0 ? 0 : totalCount;
  if (!hasActiveFilter || safeVisibleCount == safeTotalCount) {
    return safeVisibleCount.toString();
  }

  return '$safeVisibleCount of $safeTotalCount';
}

String userDeviceRecordTitle(UserDeviceRecord device) {
  if (device.deviceLabel.trim().isNotEmpty) return device.deviceLabel.trim();
  if (device.email.isNotEmpty) return device.email;
  if (device.id.isNotEmpty) return device.id;
  return 'Unknown device';
}

List<String> userDeviceRecordDetailParts(UserDeviceRecord device) {
  return List.unmodifiable([
    if (device.email.isNotEmpty) device.email,
    if (device.platform.trim().isNotEmpty) device.platform.trim(),
    if (device.country.trim().isNotEmpty) device.country.trim(),
    if (device.lastDocumentTitle.trim().isNotEmpty)
      'Last: ${device.lastDocumentTitle.trim()}',
    if (device.lastOpenSource.trim().isNotEmpty)
      'Source: ${device.lastOpenSource.trim().replaceAll('_', ' ')}',
    userDeviceStatusLabel(device.status),
  ]);
}

String userDeviceRecordDetailLabel(
  UserDeviceRecord device, {
  String timestampLabel = '',
}) {
  final parts = [
    ...userDeviceRecordDetailParts(device),
    if (timestampLabel.trim().isNotEmpty) timestampLabel.trim(),
  ];

  return parts.join(' | ');
}

String? userDeviceListLimitMessage({
  required int visibleCount,
  int displayLimit = userDeviceDefaultDisplayLimit,
}) {
  final safeVisibleCount = visibleCount < 0 ? 0 : visibleCount;
  final safeDisplayLimit = displayLimit < 1 ? 1 : displayLimit;
  if (safeVisibleCount <= safeDisplayLimit) return null;

  final deviceLabel = safeDisplayLimit == 1 ? 'device' : 'devices';
  return 'Showing first $safeDisplayLimit $deviceLabel. Narrow filters to review the rest.';
}

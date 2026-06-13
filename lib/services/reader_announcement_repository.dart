import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_access_state.dart';

enum ReaderAnnouncementAudience { all, free, premium, admin }

class ReaderAnnouncement {
  const ReaderAnnouncement({
    required this.id,
    required this.title,
    required this.message,
    this.audience = ReaderAnnouncementAudience.all,
    this.isActive = true,
    this.isPinned = false,
    this.createdAt,
    this.expiresAt,
  });

  factory ReaderAnnouncement.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return ReaderAnnouncement.fromMap(snapshot.data(), id: snapshot.id);
  }

  factory ReaderAnnouncement.fromMap(
    Map<String, dynamic> data, {
    String id = '',
  }) {
    return ReaderAnnouncement(
      id: id,
      title: data['title']?.toString().trim() ?? '',
      message: data['message']?.toString().trim() ?? '',
      audience: readReaderAnnouncementAudience(data['audience']),
      isActive: data['isActive'] != false,
      isPinned: data['isPinned'] == true,
      createdAt: data['createdAt'],
      expiresAt: _readDateTime(data['expiresAt']),
    );
  }

  final String id;
  final String title;
  final String message;
  final ReaderAnnouncementAudience audience;
  final bool isActive;
  final bool isPinned;
  final dynamic createdAt;
  final DateTime? expiresAt;

  bool get hasContent => title.isNotEmpty || message.isNotEmpty;

  bool get isExpired {
    final expiry = expiresAt;
    return expiry != null && !expiry.isAfter(DateTime.now());
  }

  bool isVisibleFor(UserAccessState access) {
    if (!isActive || isExpired || !hasContent) return false;

    return switch (audience) {
      ReaderAnnouncementAudience.all => true,
      ReaderAnnouncementAudience.free => !access.canAccessMainVault,
      ReaderAnnouncementAudience.premium => access.canAccessMainVault,
      ReaderAnnouncementAudience.admin => access.isAdmin,
    };
  }

  static List<ReaderAnnouncement> sortForDashboard(
    Iterable<ReaderAnnouncement> announcements,
  ) {
    final sorted = List<ReaderAnnouncement>.from(announcements);
    sorted.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return _compareCreatedAt(a.createdAt, b.createdAt);
    });
    return sorted;
  }

  static int _compareCreatedAt(dynamic a, dynamic b) {
    if (a is Timestamp && b is Timestamp) return b.compareTo(a);
    if (a is Timestamp) return -1;
    if (b is Timestamp) return 1;
    return 0;
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class ReaderAnnouncementDraft {
  const ReaderAnnouncementDraft({
    required this.title,
    required this.message,
    this.audience = ReaderAnnouncementAudience.all,
    this.isPinned = false,
    this.expiresAt,
  });

  final String title;
  final String message;
  final ReaderAnnouncementAudience audience;
  final bool isPinned;
  final DateTime? expiresAt;

  Map<String, dynamic> toFirestore({required Object createdAt}) {
    return {
      'title': title.trim(),
      'message': message.trim(),
      'audience': readerAnnouncementAudienceKey(audience),
      'isActive': true,
      'isPinned': isPinned,
      'expiresAt': expiresAt,
      'createdAt': createdAt,
    };
  }
}

abstract interface class ReaderAnnouncementStore {
  Future<List<ReaderAnnouncement>> listForUser({
    required UserAccessState access,
    int limit = 20,
  });

  Future<void> save(ReaderAnnouncementDraft announcement);
}

class ReaderAnnouncementRepository implements ReaderAnnouncementStore {
  ReaderAnnouncementRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<List<ReaderAnnouncement>> listForUser({
    required UserAccessState access,
    int limit = 20,
  }) async {
    final snapshot = await _collection.limit(limit < 1 ? 1 : limit).get();
    final visibleAnnouncements = snapshot.docs
        .map(ReaderAnnouncement.fromSnapshot)
        .where((announcement) => announcement.isVisibleFor(access));

    return List.unmodifiable(
      ReaderAnnouncement.sortForDashboard(visibleAnnouncements),
    );
  }

  @override
  Future<void> save(ReaderAnnouncementDraft announcement) {
    return _collection.add(
      announcement.toFirestore(createdAt: FieldValue.serverTimestamp()),
    );
  }

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('reader_announcements');
}

ReaderAnnouncementAudience readReaderAnnouncementAudience(dynamic value) {
  return switch (value?.toString().trim().toLowerCase()) {
    'free' || 'free_users' => ReaderAnnouncementAudience.free,
    'premium' ||
    'subscriber' ||
    'subscribers' => ReaderAnnouncementAudience.premium,
    'admin' || 'admins' => ReaderAnnouncementAudience.admin,
    _ => ReaderAnnouncementAudience.all,
  };
}

String readerAnnouncementAudienceKey(ReaderAnnouncementAudience audience) {
  return switch (audience) {
    ReaderAnnouncementAudience.all => 'all',
    ReaderAnnouncementAudience.free => 'free',
    ReaderAnnouncementAudience.premium => 'premium',
    ReaderAnnouncementAudience.admin => 'admin',
  };
}

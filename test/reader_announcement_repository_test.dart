import 'package:ancient_secure_docs/services/reader_announcement_repository.dart';
import 'package:ancient_secure_docs/services/user_access_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads announcement data with safe defaults', () {
    final announcement = ReaderAnnouncement.fromMap({
      'title': ' Vault update ',
      'message': ' Protected reader is live. ',
      'audience': 'premium',
      'isPinned': true,
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(2000),
      'expiresAt': '2026-07-01T12:00:00.000',
    }, id: 'announcement-1');

    expect(announcement.id, 'announcement-1');
    expect(announcement.title, 'Vault update');
    expect(announcement.message, 'Protected reader is live.');
    expect(announcement.audience, ReaderAnnouncementAudience.premium);
    expect(announcement.isActive, isTrue);
    expect(announcement.isPinned, isTrue);
    expect(announcement.hasContent, isTrue);
    expect(announcement.expiresAt, DateTime(2026, 7, 1, 12));
  });

  test('filters announcements by audience and expiry', () {
    const free = UserAccessState();
    const premium = UserAccessState(
      accessLevel: 'premium',
      hasActiveSubscription: true,
      subscriptionStatus: UserSubscriptionStatus.active,
    );
    const admin = UserAccessState(isAdmin: true);

    final all = ReaderAnnouncement.fromMap({
      'title': 'All readers',
      'audience': 'all',
    });
    final freeOnly = ReaderAnnouncement.fromMap({
      'title': 'Free readers',
      'audience': 'free',
    });
    final premiumOnly = ReaderAnnouncement.fromMap({
      'title': 'Premium readers',
      'audience': 'premium',
    });
    final adminOnly = ReaderAnnouncement.fromMap({
      'title': 'Admins',
      'audience': 'admin',
    });
    final expired = ReaderAnnouncement.fromMap({
      'title': 'Old update',
      'expiresAt': DateTime.now().subtract(const Duration(days: 1)),
    });
    final empty = ReaderAnnouncement.fromMap({'audience': 'all'});

    expect(all.isVisibleFor(free), isTrue);
    expect(freeOnly.isVisibleFor(free), isTrue);
    expect(freeOnly.isVisibleFor(premium), isFalse);
    expect(premiumOnly.isVisibleFor(premium), isTrue);
    expect(adminOnly.isVisibleFor(admin), isTrue);
    expect(adminOnly.isVisibleFor(premium), isFalse);
    expect(expired.isVisibleFor(admin), isFalse);
    expect(empty.isVisibleFor(admin), isFalse);
  });

  test('sorts pinned announcements before newer normal announcements', () {
    final pinnedOlder = ReaderAnnouncement.fromMap({
      'title': 'Pinned',
      'isPinned': true,
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(1000),
    }, id: 'pinned');
    final newer = ReaderAnnouncement.fromMap({
      'title': 'Newer',
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(3000),
    }, id: 'newer');
    final older = ReaderAnnouncement.fromMap({
      'title': 'Older',
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(2000),
    }, id: 'older');

    final sorted = ReaderAnnouncement.sortForDashboard([
      older,
      newer,
      pinnedOlder,
    ]);

    expect(sorted.map((item) => item.id), ['pinned', 'newer', 'older']);
  });

  test('builds announcement payloads for Firestore', () {
    final expiresAt = DateTime(2026, 7, 1, 12);
    final draft = ReaderAnnouncementDraft(
      title: ' Trial update ',
      message: ' Trial users can explore the free zone. ',
      audience: ReaderAnnouncementAudience.free,
      isPinned: true,
      expiresAt: expiresAt,
    );

    expect(draft.toFirestore(createdAt: 'now'), {
      'title': 'Trial update',
      'message': 'Trial users can explore the free zone.',
      'audience': 'free',
      'isActive': true,
      'isPinned': true,
      'expiresAt': expiresAt,
      'createdAt': 'now',
    });
    expect(
      readReaderAnnouncementAudience('subscribers'),
      ReaderAnnouncementAudience.premium,
    );
    expect(
      readerAnnouncementAudienceKey(ReaderAnnouncementAudience.admin),
      'admin',
    );
  });
}

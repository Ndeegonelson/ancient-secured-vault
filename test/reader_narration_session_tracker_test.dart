import 'package:ancient_secure_docs/services/reader_narration_session_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tracks listening time, narrated pages, and document completion', () {
    var now = DateTime(2026, 6, 4, 10);
    final tracker = ReaderNarrationSessionTracker(clock: () => now);

    tracker.beginDocumentNarration();
    tracker.observe(isPlaying: true, pageNumber: 4, progressPercent: 10);
    now = now.add(const Duration(seconds: 12));
    tracker.observe(isPlaying: false, pageNumber: 4, progressPercent: 45);
    tracker.observe(isPlaying: true, pageNumber: 5, progressPercent: 5);
    now = now.add(const Duration(seconds: 8));
    tracker.observe(isPlaying: false, pageNumber: 5, progressPercent: 100);

    final summary = tracker.snapshot();

    expect(summary.listeningSeconds, 20);
    expect(summary.pagesNarrated, [4, 5]);
    expect(summary.completedPages, [5]);
    expect(summary.pageProgress, {4: 45, 5: 100});
    expect(summary.highestProgressPercent, 100);
  });

  test(
    'tracks selected passage completion without completing its PDF page',
    () {
      final tracker = ReaderNarrationSessionTracker();

      tracker.beginSelectedPassage();
      tracker.observe(isPlaying: true, pageNumber: 7, progressPercent: 25);
      tracker.observe(isPlaying: false, pageNumber: 7, progressPercent: 100);

      final summary = tracker.snapshot();

      expect(summary.pagesNarrated, [7]);
      expect(summary.completedPages, isEmpty);
      expect(summary.selectedPassagesStarted, 1);
      expect(summary.selectedPassagesCompleted, 1);
    },
  );

  test('finish includes currently active listening time', () {
    var now = DateTime(2026, 6, 4, 10);
    final tracker = ReaderNarrationSessionTracker(clock: () => now);

    tracker.beginDocumentNarration();
    tracker.observe(isPlaying: true, pageNumber: 1, progressPercent: 10);
    now = now.add(const Duration(seconds: 9));

    final summary = tracker.finish();

    expect(summary.listeningSeconds, 9);
    expect(summary.finished, isTrue);
  });

  test('does not assign stale stopped progress to a newly selected mode', () {
    final tracker = ReaderNarrationSessionTracker();

    tracker.beginSelectedPassage();
    tracker.observe(isPlaying: true, pageNumber: 7, progressPercent: 40);
    tracker.beginDocumentNarration();
    tracker.observe(isPlaying: false, pageNumber: 7, progressPercent: 100);
    tracker.observe(isPlaying: true, pageNumber: 8, progressPercent: 5);

    final summary = tracker.snapshot();

    expect(summary.completedPages, isEmpty);
    expect(summary.pageProgress, {8: 5});
    expect(summary.selectedPassagesCompleted, 0);
  });
}

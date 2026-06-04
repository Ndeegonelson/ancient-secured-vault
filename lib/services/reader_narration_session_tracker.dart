enum ReaderNarrationMode { document, selectedPassage }

class ReaderNarrationSessionSummary {
  const ReaderNarrationSessionSummary({
    required this.startedAt,
    required this.updatedAt,
    required this.listeningDuration,
    required this.pagesNarrated,
    required this.completedPages,
    required this.pageProgress,
    required this.highestProgressPercent,
    required this.selectedPassagesStarted,
    required this.selectedPassagesCompleted,
    required this.finished,
  });

  final DateTime startedAt;
  final DateTime updatedAt;
  final Duration listeningDuration;
  final List<int> pagesNarrated;
  final List<int> completedPages;
  final Map<int, int> pageProgress;
  final int highestProgressPercent;
  final int selectedPassagesStarted;
  final int selectedPassagesCompleted;
  final bool finished;

  int get listeningSeconds => listeningDuration.inSeconds;
  bool get hasActivity =>
      listeningDuration > Duration.zero ||
      pagesNarrated.isNotEmpty ||
      selectedPassagesStarted > 0;
}

class ReaderNarrationSessionTracker {
  ReaderNarrationSessionTracker({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Set<int> _pagesNarrated = {};
  final Set<int> _completedPages = {};
  final Map<int, int> _pageProgress = {};
  DateTime? _startedAt;
  DateTime? _activeSince;
  Duration _listeningDuration = Duration.zero;
  ReaderNarrationMode _mode = ReaderNarrationMode.document;
  int _highestProgressPercent = 0;
  int _selectedPassagesStarted = 0;
  int _selectedPassagesCompleted = 0;
  bool _selectedPassageCompletionRecorded = false;
  bool _awaitingPlaybackAfterModeChange = false;

  void beginDocumentNarration() {
    _mode = ReaderNarrationMode.document;
    _awaitingPlaybackAfterModeChange = true;
  }

  void beginSelectedPassage() {
    _mode = ReaderNarrationMode.selectedPassage;
    _selectedPassagesStarted++;
    _selectedPassageCompletionRecorded = false;
    _awaitingPlaybackAfterModeChange = true;
  }

  void observe({
    required bool isPlaying,
    required int? pageNumber,
    required int progressPercent,
  }) {
    final now = _clock();
    _syncListeningState(isPlaying: isPlaying, now: now);

    if (_awaitingPlaybackAfterModeChange) {
      if (!isPlaying) return;
      _awaitingPlaybackAfterModeChange = false;
    }

    final safeProgress = progressPercent.clamp(0, 100);

    if (pageNumber != null && (isPlaying || safeProgress > 0)) {
      _pagesNarrated.add(pageNumber);
    }

    if (safeProgress > _highestProgressPercent) {
      _highestProgressPercent = safeProgress;
    }

    if (pageNumber == null) return;

    if (_mode == ReaderNarrationMode.document) {
      final previousProgress = _pageProgress[pageNumber] ?? 0;
      if (safeProgress > previousProgress) {
        _pageProgress[pageNumber] = safeProgress;
      }
      if (safeProgress >= 100) {
        _completedPages.add(pageNumber);
      }
      return;
    }

    if (safeProgress >= 100 && !_selectedPassageCompletionRecorded) {
      _selectedPassageCompletionRecorded = true;
      _selectedPassagesCompleted++;
    }
  }

  ReaderNarrationSessionSummary snapshot({bool finished = false}) {
    final now = _clock();
    final listeningDuration =
        _listeningDuration +
        (_activeSince == null ? Duration.zero : now.difference(_activeSince!));
    final pagesNarrated = _pagesNarrated.toList()..sort();
    final completedPages = _completedPages.toList()..sort();

    return ReaderNarrationSessionSummary(
      startedAt: _startedAt ?? now,
      updatedAt: now,
      listeningDuration: listeningDuration,
      pagesNarrated: pagesNarrated,
      completedPages: completedPages,
      pageProgress: Map.unmodifiable(_pageProgress),
      highestProgressPercent: _highestProgressPercent,
      selectedPassagesStarted: _selectedPassagesStarted,
      selectedPassagesCompleted: _selectedPassagesCompleted,
      finished: finished,
    );
  }

  ReaderNarrationSessionSummary finish() {
    final now = _clock();
    _syncListeningState(isPlaying: false, now: now);
    return snapshot(finished: true);
  }

  void _syncListeningState({required bool isPlaying, required DateTime now}) {
    if (isPlaying) {
      _startedAt ??= now;
      _activeSince ??= now;
      return;
    }

    final activeSince = _activeSince;
    if (activeSince == null) return;

    _listeningDuration += now.difference(activeSince);
    _activeSince = null;
  }
}

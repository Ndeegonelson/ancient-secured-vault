import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../services/reader_narration_progress_repository.dart';
import '../services/reader_narration_access_policy.dart';
import '../services/reader_narration_playback_coordinator.dart';
import '../services/reader_narration_playback_router.dart';
import '../services/reader_narration_session_tracker.dart';
import '../services/reader_narration_voice.dart';
import '../services/reader_narration_voice_catalog_presenter.dart';
import '../services/reader_tts_service.dart';

class ReaderNarrationDialog extends StatelessWidget {
  const ReaderNarrationDialog({
    super.key,
    required this.service,
    required this.playbackCoordinator,
    required this.pageNumber,
    required this.narrationText,
    required this.savedCheckpoint,
    required this.accessPolicy,
    required this.voiceCatalog,
    required this.sessionTracker,
    this.title = 'Document Narration',
    required this.onLanguageChanged,
    required this.onVoiceChanged,
    required this.onRateChangeEnd,
    required this.onPlay,
    required this.onPause,
    required this.onResume,
    required this.onJumpBackward,
    required this.onJumpForward,
    required this.onStop,
  });

  final ReaderTtsService service;
  final ReaderNarrationPlaybackCoordinator playbackCoordinator;
  final int pageNumber;
  final Future<String> narrationText;
  final ReaderNarrationCheckpoint? savedCheckpoint;
  final ReaderNarrationAccessPolicy accessPolicy;
  final ReaderNarrationVoiceCatalogViewModel Function() voiceCatalog;
  final ReaderNarrationSessionTracker sessionTracker;
  final String title;
  final Future<void> Function(ReaderNarrationLanguage language)
  onLanguageChanged;
  final Future<void> Function(ReaderNarrationVoice voice) onVoiceChanged;
  final Future<void> Function(double rate) onRateChangeEnd;
  final Future<void> Function(String text) onPlay;
  final Future<void> Function() onPause;
  final Future<void> Function() onResume;
  final Future<void> Function(String text) onJumpBackward;
  final Future<void> Function(String text) onJumpForward;
  final Future<void> Function() onStop;

  List<Listenable> get _narrationAnimations {
    final cloudSession = playbackCoordinator.cloudSession;
    return [
      service,
      if (cloudSession is Listenable) cloudSession as Listenable,
    ];
  }

  String get stateLabel {
    switch (playbackCoordinator.state) {
      case ReaderNarrationRouterState.playing:
        return 'Playing';
      case ReaderNarrationRouterState.paused:
        return 'Paused';
      case ReaderNarrationRouterState.stopped:
        return 'Stopped';
      case ReaderNarrationRouterState.error:
        return 'Needs attention';
      case ReaderNarrationRouterState.idle:
        return 'Ready';
    }
  }

  String sessionStatus(ReaderNarrationSessionSummary summary) {
    final seconds = summary.listeningSeconds;
    final listeningLabel = seconds >= 60
        ? '${seconds ~/ 60}m ${seconds % 60}s'
        : '${seconds}s';
    final pageLabel = summary.pagesNarrated.length == 1 ? 'page' : 'pages';
    final completedLabel = summary.completedPages.length == 1
        ? 'page completed'
        : 'pages completed';

    return '$listeningLabel listening | '
        '${summary.pagesNarrated.length} $pageLabel narrated | '
        '${summary.completedPages.length} $completedLabel';
  }

  _NarrationPassageView _passageForRange(String text, int start, int end) {
    if (text.isEmpty) return const _NarrationPassageView.empty();

    final safeStart = start.clamp(0, text.length - 1);
    final safeEnd = end.clamp(safeStart + 1, text.length);
    final windowStart = (safeStart - 85).clamp(0, text.length);
    final windowEnd = (safeEnd + 125).clamp(0, text.length);
    final prefix = windowStart > 0 ? '... ' : '';
    final suffix = windowEnd < text.length ? ' ...' : '';
    final passage = _cleanPassage(text.substring(windowStart, windowEnd));
    final prefixLength = prefix.length;
    final sourcePrefix = _cleanPassage(text.substring(windowStart, safeStart));

    return _NarrationPassageView(
      text: '$prefix$passage$suffix',
      highlightStart: prefixLength + sourcePrefix.length,
      highlightEnd: prefixLength + sourcePrefix.length + (safeEnd - safeStart),
    );
  }

  String _cleanPassage(String passage) {
    return passage.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _voiceChoiceLabel(ReaderNarrationVoice voice) {
    final role = voice.provider == ReaderNarrationVoiceProvider.cloudAi
        ? 'Cloud'
        : 'Read-along';
    return '${voice.label} | $role';
  }

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: AnimatedBuilder(
        animation: Listenable.merge(_narrationAnimations),
        builder: (context, child) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0F1117),
            title: Text(
              title,
              style: const TextStyle(color: Colors.greenAccent),
            ),
            content: SizedBox(
              width: 460,
              child: FutureBuilder<String>(
                future: narrationText,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(
                      snapshot.error.toString(),
                      style: const TextStyle(color: Colors.redAccent),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Colors.greenAccent,
                        ),
                      ),
                    );
                  }

                  final text = snapshot.data!.trim();
                  final playbackStatus = playbackCoordinator.status;
                  final isCloudNarration = playbackCoordinator.isUsingCloud;
                  final activePageNumber = service.pageNumber ?? pageNumber;
                  final activeText =
                      service.pageNumber != null &&
                          service.pageNumber != pageNumber &&
                          service.lastText.isNotEmpty
                      ? service.lastText
                      : text;
                  final hasReadableText = activeText.isNotEmpty;
                  final hasActiveNarration =
                      service.lastText == activeText || isCloudNarration;
                  final passageView = isCloudNarration
                      ? _passageForRange(
                          activeText,
                          playbackStatus.currentCharacterStart,
                          playbackStatus.currentCharacterEnd,
                        )
                      : _NarrationPassageView(
                          text: hasActiveNarration
                              ? service.currentPassage.trim()
                              : '',
                          highlightStart: service.currentPassageHighlightStart,
                          highlightEnd: service.currentPassageHighlightEnd,
                        );
                  final currentPassage = passageView.text;
                  final highlightStart = passageView.highlightStart.clamp(
                    0,
                    currentPassage.length,
                  );
                  final highlightEnd = passageView.highlightEnd.clamp(
                    highlightStart,
                    currentPassage.length,
                  );
                  final liveProgressPercent = isCloudNarration
                      ? playbackStatus.progressPercent
                      : service.progressPercent;
                  final hasLiveResume = isCloudNarration
                      ? liveProgressPercent > 0 && liveProgressPercent < 100
                      : hasActiveNarration &&
                            service.pageNumber == activePageNumber &&
                            service.hasResumableProgress;
                  final resumePercent = hasLiveResume
                      ? liveProgressPercent
                      : activePageNumber == pageNumber
                      ? savedCheckpoint?.progressPercent
                      : null;
                  final showSavedProgress =
                      playbackCoordinator.state ==
                          ReaderNarrationRouterState.stopped &&
                      liveProgressPercent == 0 &&
                      resumePercent != null;
                  final displayProgressPercent = showSavedProgress
                      ? resumePercent
                      : liveProgressPercent;
                  final sessionSummary = sessionTracker.snapshot();
                  final voiceCatalogView = voiceCatalog();
                  final rawErrorMessage =
                      playbackStatus.errorMessage ?? service.errorMessage;
                  final hasNarrationProgress =
                      displayProgressPercent > 0 ||
                      playbackCoordinator.isPlaying ||
                      playbackCoordinator.isPaused ||
                      sessionSummary.hasActivity;
                  final errorMessage =
                      rawErrorMessage == 'Browser narration could not start.' &&
                          hasNarrationProgress
                      ? null
                      : rawErrorMessage;

                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Page $activePageNumber | $stateLabel',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          hasReadableText
                              ? '${activeText.length} readable characters found.'
                              : 'No readable text was found on this page.',
                          style: TextStyle(
                            color: hasReadableText
                                ? Colors.white54
                                : Colors.orangeAccent,
                          ),
                        ),
                        if (currentPassage.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          const Divider(color: Colors.white12),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: RichText(
                                textAlign: TextAlign.center,
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 16,
                                    height: 1.45,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: currentPassage.substring(
                                        0,
                                        highlightStart,
                                      ),
                                    ),
                                    if (highlightEnd > highlightStart)
                                      TextSpan(
                                        text: currentPassage.substring(
                                          highlightStart,
                                          highlightEnd,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.black,
                                          backgroundColor: Colors.amberAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    TextSpan(
                                      text: currentPassage.substring(
                                        highlightEnd,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Divider(color: Colors.white12),
                        ],
                        if (hasActiveNarration) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: displayProgressPercent / 100,
                                  minHeight: 4,
                                  backgroundColor: Colors.white12,
                                  color: Colors.greenAccent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '$displayProgressPercent%',
                                style: const TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                        ],
                        if (sessionSummary.hasActivity) ...[
                          const SizedBox(height: 8),
                          Text(
                            sessionStatus(sessionSummary),
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (resumePercent != null && resumePercent > 0) ...[
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: hasReadableText
                                ? playbackCoordinator.isPaused
                                      ? onResume
                                      : () => onPlay(activeText)
                                : null,
                            icon: const Icon(Icons.restore),
                            label: Text('Resume narration ($resumePercent%)'),
                          ),
                        ],
                        if (errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            errorMessage,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ],
                        const SizedBox(height: 20),
                        const Text(
                          'Language',
                          style: TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          accessPolicy.summary,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<ReaderNarrationLanguage>(
                          segments: ReaderNarrationLanguage.values
                              .map(
                                (language) =>
                                    ButtonSegment<ReaderNarrationLanguage>(
                                      value: language,
                                      label: Text(language.label),
                                    ),
                              )
                              .toList(),
                          selected: {service.language},
                          onSelectionChanged: (selection) {
                            onLanguageChanged(selection.first);
                          },
                        ),
                        if (service.automaticLanguageSummary.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            service.automaticLanguageSummary,
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    voiceCatalogView.assignedNarratorLabel,
                                    style: TextStyle(
                                      color:
                                          voiceCatalogView
                                              .assignedNarratorAvailable
                                          ? Colors.white54
                                          : Colors.orangeAccent,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    voiceCatalogView.availabilitySummary,
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Refresh narration voices',
                              onPressed: service.refreshVoices,
                              icon: const Icon(Icons.refresh),
                              color: Colors.greenAccent,
                            ),
                          ],
                        ),
                        if (voiceCatalogView.selectableVoices.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<ReaderNarrationVoice>(
                            key: ValueKey(
                              '${service.effectiveLanguage.name}|'
                              '${voiceCatalogView.selectedVoice?.id}',
                            ),
                            initialValue: voiceCatalogView.selectedVoice,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1A1D25),
                            iconEnabledColor: Colors.greenAccent,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Choose narrator',
                              labelStyle: TextStyle(color: Colors.white70),
                              floatingLabelStyle: TextStyle(
                                color: Colors.greenAccent,
                              ),
                              filled: true,
                              fillColor: Color(0xFF151821),
                              border: OutlineInputBorder(),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white24),
                              ),
                            ),
                            items: voiceCatalogView.selectableVoices
                                .map(
                                  (voice) =>
                                      DropdownMenuItem<ReaderNarrationVoice>(
                                        value: voice,
                                        child: Text(
                                          _voiceChoiceLabel(voice),
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                )
                                .toList(),
                            onChanged: (voice) async {
                              if (voice != null) {
                                await onVoiceChanged(voice);
                              }
                            },
                          ),
                        ],
                        if (voiceCatalogView.helperMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            voiceCatalogView.helperMessage!,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          'Speed: ${service.rate.toStringAsFixed(2)}x',
                          style: const TextStyle(color: Colors.white),
                        ),
                        Slider(
                          value: service.rate,
                          min: ReaderTtsService.minimumRate,
                          max: ReaderTtsService.maximumRate,
                          divisions: 26,
                          label: '${service.rate.toStringAsFixed(2)}x',
                          onChanged: service.setRate,
                          onChangeEnd: onRateChangeEnd,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            IconButton(
                              constraints: const BoxConstraints.tightFor(
                                width: 42,
                                height: 42,
                              ),
                              padding: EdgeInsets.zero,
                              tooltip:
                                  'Previous paragraph; repeat for section/page start',
                              onPressed: hasReadableText
                                  ? () => onJumpBackward(activeText)
                                  : null,
                              icon: const Icon(Icons.fast_rewind),
                              color: Colors.white70,
                            ),
                            IconButton(
                              constraints: const BoxConstraints.tightFor(
                                width: 42,
                                height: 42,
                              ),
                              padding: EdgeInsets.zero,
                              tooltip:
                                  playbackCoordinator.isPaused ||
                                      resumePercent != null
                                  ? 'Resume narration'
                                  : 'Play page narration',
                              onPressed: hasReadableText
                                  ? playbackCoordinator.isPaused
                                        ? onResume
                                        : () => onPlay(activeText)
                                  : null,
                              icon: const Icon(Icons.play_arrow),
                              color: Colors.greenAccent,
                            ),
                            IconButton(
                              constraints: const BoxConstraints.tightFor(
                                width: 42,
                                height: 42,
                              ),
                              padding: EdgeInsets.zero,
                              tooltip: 'Pause narration',
                              onPressed: playbackCoordinator.isPlaying
                                  ? onPause
                                  : null,
                              icon: const Icon(Icons.pause),
                              color: Colors.orangeAccent,
                            ),
                            IconButton(
                              constraints: const BoxConstraints.tightFor(
                                width: 42,
                                height: 42,
                              ),
                              padding: EdgeInsets.zero,
                              tooltip: 'Stop narration',
                              onPressed:
                                  playbackCoordinator.state ==
                                      ReaderNarrationRouterState.idle
                                  ? null
                                  : onStop,
                              icon: const Icon(Icons.stop),
                              color: Colors.redAccent,
                            ),
                            IconButton(
                              constraints: const BoxConstraints.tightFor(
                                width: 42,
                                height: 42,
                              ),
                              padding: EdgeInsets.zero,
                              tooltip:
                                  'Next paragraph; repeat for section/page end',
                              onPressed: hasReadableText
                                  ? () => onJumpForward(activeText)
                                  : null,
                              icon: const Icon(Icons.fast_forward),
                              color: Colors.white70,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.greenAccent),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NarrationPassageView {
  const _NarrationPassageView({
    required this.text,
    required this.highlightStart,
    required this.highlightEnd,
  });

  const _NarrationPassageView.empty()
    : text = '',
      highlightStart = 0,
      highlightEnd = 0;

  final String text;
  final int highlightStart;
  final int highlightEnd;
}

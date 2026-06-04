import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../services/reader_narration_progress_repository.dart';
import '../services/reader_narration_access_policy.dart';
import '../services/reader_narration_session_tracker.dart';
import '../services/reader_narration_voice.dart';
import '../services/reader_tts_service.dart';

class ReaderNarrationDialog extends StatelessWidget {
  const ReaderNarrationDialog({
    super.key,
    required this.service,
    required this.pageNumber,
    required this.narrationText,
    required this.savedCheckpoint,
    required this.accessPolicy,
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
  final int pageNumber;
  final Future<String> narrationText;
  final ReaderNarrationCheckpoint? savedCheckpoint;
  final ReaderNarrationAccessPolicy accessPolicy;
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

  String get stateLabel {
    switch (service.state) {
      case ReaderNarrationState.playing:
        return 'Playing';
      case ReaderNarrationState.paused:
        return 'Paused';
      case ReaderNarrationState.stopped:
        return 'Stopped';
      case ReaderNarrationState.error:
        return 'Needs attention';
      case ReaderNarrationState.idle:
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

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: AnimatedBuilder(
        animation: service,
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
                  final activePageNumber = service.pageNumber ?? pageNumber;
                  final activeText =
                      service.pageNumber != null &&
                          service.pageNumber != pageNumber &&
                          service.lastText.isNotEmpty
                      ? service.lastText
                      : text;
                  final hasReadableText = activeText.isNotEmpty;
                  final hasActiveNarration = service.lastText == activeText;
                  final currentPassage = hasActiveNarration
                      ? service.currentPassage.trim()
                      : '';
                  final highlightStart = service.currentPassageHighlightStart
                      .clamp(0, currentPassage.length);
                  final highlightEnd = service.currentPassageHighlightEnd.clamp(
                    highlightStart,
                    currentPassage.length,
                  );
                  final hasLiveResume =
                      hasActiveNarration &&
                      service.pageNumber == activePageNumber &&
                      service.hasResumableProgress;
                  final resumePercent = hasLiveResume
                      ? service.progressPercent
                      : activePageNumber == pageNumber
                      ? savedCheckpoint?.progressPercent
                      : null;
                  final showSavedProgress =
                      service.state == ReaderNarrationState.stopped &&
                      service.progressPercent == 0 &&
                      resumePercent != null;
                  final displayProgressPercent = showSavedProgress
                      ? resumePercent
                      : service.progressPercent;
                  final sessionSummary = sessionTracker.snapshot();

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
                                ? service.isPaused
                                      ? onResume
                                      : () => onPlay(activeText)
                                : null,
                            icon: const Icon(Icons.restore),
                            label: Text('Resume narration ($resumePercent%)'),
                          ),
                        ],
                        if (service.errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            service.errorMessage!,
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
                                    service.activeVoice == null
                                        ? service.activeLocale == null
                                              ? 'Assigned narrator: unavailable'
                                              : 'Assigned narrator: ${service.activeLocale}'
                                        : 'Assigned narrator: ${service.activeVoice!.label}',
                                    style: TextStyle(
                                      color: service.activeLocale == null
                                          ? Colors.orangeAccent
                                          : Colors.white54,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    service.detectedVoiceSummary,
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Refresh browser voices',
                              onPressed: service.refreshVoices,
                              icon: const Icon(Icons.refresh),
                              color: Colors.greenAccent,
                            ),
                          ],
                        ),
                        if (accessPolicy.canChooseVoice &&
                            service.availableVoicesForActiveLanguage.length >
                                1) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<ReaderNarrationVoice>(
                            key: ValueKey(
                              '${service.effectiveLanguage.name}|'
                              '${service.activeVoice?.id}',
                            ),
                            initialValue: service.activeVoice,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1A1D25),
                            iconEnabledColor: Colors.greenAccent,
                            style: const TextStyle(color: Colors.white70),
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
                            items: service.availableVoicesForActiveLanguage
                                .map(
                                  (voice) =>
                                      DropdownMenuItem<ReaderNarrationVoice>(
                                        value: voice,
                                        child: Text(
                                          voice.label,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                )
                                .toList(),
                            onChanged: (voice) {
                              if (voice != null) {
                                onVoiceChanged(voice);
                              }
                            },
                          ),
                        ] else if (accessPolicy.canChooseVoice) ...[
                          const SizedBox(height: 8),
                          Text(
                            service.availableVoicesForActiveLanguage.isEmpty
                                ? 'No compatible browser narrator was detected.'
                                : '1 compatible browser narrator detected. '
                                      'Additional premium narrators require '
                                      'a cloud voice provider.',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          const Text(
                            'The narrator is assigned automatically on the free plan.',
                            style: TextStyle(
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
                          divisions: 15,
                          label: '${service.rate.toStringAsFixed(2)}x',
                          onChanged: service.setRate,
                          onChangeEnd: onRateChangeEnd,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip:
                                  'Previous paragraph; repeat for section/page start',
                              onPressed: hasReadableText
                                  ? () => onJumpBackward(activeText)
                                  : null,
                              icon: const Icon(Icons.fast_rewind),
                              color: Colors.white70,
                            ),
                            IconButton(
                              tooltip: service.isPaused || resumePercent != null
                                  ? 'Resume narration'
                                  : 'Play page narration',
                              onPressed: hasReadableText
                                  ? service.isPaused
                                        ? onResume
                                        : () => onPlay(activeText)
                                  : null,
                              icon: const Icon(Icons.play_arrow),
                              color: Colors.greenAccent,
                            ),
                            IconButton(
                              tooltip: 'Pause narration',
                              onPressed: service.isPlaying ? onPause : null,
                              icon: const Icon(Icons.pause),
                              color: Colors.orangeAccent,
                            ),
                            IconButton(
                              tooltip: 'Stop narration',
                              onPressed:
                                  service.state == ReaderNarrationState.idle
                                  ? null
                                  : onStop,
                              icon: const Icon(Icons.stop),
                              color: Colors.redAccent,
                            ),
                            IconButton(
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

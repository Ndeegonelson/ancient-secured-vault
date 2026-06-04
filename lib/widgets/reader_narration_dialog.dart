import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../services/reader_tts_service.dart';

class ReaderNarrationDialog extends StatelessWidget {
  const ReaderNarrationDialog({
    super.key,
    required this.service,
    required this.pageNumber,
    required this.narrationText,
    required this.onLanguageChanged,
    required this.onRateChangeEnd,
    required this.onPlay,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  final ReaderTtsService service;
  final int pageNumber;
  final Future<String> narrationText;
  final Future<void> Function(ReaderNarrationLanguage language)
  onLanguageChanged;
  final Future<void> Function(double rate) onRateChangeEnd;
  final Future<void> Function(String text) onPlay;
  final Future<void> Function() onPause;
  final Future<void> Function() onResume;
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

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: AnimatedBuilder(
        animation: service,
        builder: (context, child) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0F1117),
            title: const Text(
              'Page Narration',
              style: TextStyle(color: Colors.greenAccent),
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
                  final hasReadableText = text.isNotEmpty;
                  final currentWord = service.currentWord.trim();

                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Page $pageNumber | $stateLabel',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          hasReadableText
                              ? '${text.length} readable characters found.'
                              : 'No readable text was found on this page.',
                          style: TextStyle(
                            color: hasReadableText
                                ? Colors.white54
                                : Colors.orangeAccent,
                          ),
                        ),
                        if (currentWord.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Current word: $currentWord',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.greenAccent),
                          ),
                        ],
                        if (service.lastText.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: service.progress,
                                  minHeight: 4,
                                  backgroundColor: Colors.white12,
                                  color: Colors.greenAccent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${service.progressPercent}%',
                                style: const TextStyle(color: Colors.white54),
                              ),
                            ],
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
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    service.activeLocale == null
                                        ? 'Selected voice: unavailable'
                                        : 'Active browser voice: ${service.activeLocale}',
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
                              tooltip: service.isPaused
                                  ? 'Resume narration'
                                  : 'Play page narration',
                              onPressed: hasReadableText
                                  ? service.isPaused
                                        ? onResume
                                        : () => onPlay(text)
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

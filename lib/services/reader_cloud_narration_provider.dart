import 'dart:typed_data';

import 'reader_narration_voice.dart';

enum ReaderCloudNarrationProviderState {
  notConfigured,
  ready,
  temporarilyUnavailable,
}

class ReaderCloudNarrationProviderStatus {
  const ReaderCloudNarrationProviderStatus({
    required this.state,
    required this.message,
  });

  final ReaderCloudNarrationProviderState state;
  final String message;

  bool get isReady => state == ReaderCloudNarrationProviderState.ready;
}

class ReaderCloudNarrationProviderCapabilities {
  const ReaderCloudNarrationProviderCapabilities({
    required this.supportsStreamingAudio,
    required this.supportsWordTimings,
    required this.supportsVoiceStyles,
    required this.supportsCustomVoices,
  });

  final bool supportsStreamingAudio;
  final bool supportsWordTimings;
  final bool supportsVoiceStyles;
  final bool supportsCustomVoices;
}

class ReaderCloudNarrationSynthesisRequest {
  const ReaderCloudNarrationSynthesisRequest({
    required this.text,
    required this.voice,
    required this.rate,
    this.startCharacter = 0,
  });

  final String text;
  final ReaderNarrationVoice voice;
  final double rate;
  final int startCharacter;

  int get endCharacter => startCharacter + text.length;
}

class ReaderCloudNarrationTimingCue {
  const ReaderCloudNarrationTimingCue({
    required this.startCharacter,
    required this.endCharacter,
    required this.audioOffset,
  });

  final int startCharacter;
  final int endCharacter;
  final Duration audioOffset;
}

class ReaderCloudNarrationAudioSegment {
  const ReaderCloudNarrationAudioSegment({
    required this.audioBytes,
    required this.contentType,
    required this.startCharacter,
    required this.endCharacter,
    this.duration,
    this.timingCues = const [],
  });

  final Uint8List audioBytes;
  final String contentType;
  final int startCharacter;
  final int endCharacter;
  final Duration? duration;
  final List<ReaderCloudNarrationTimingCue> timingCues;

  bool get isEmpty => audioBytes.isEmpty;

  bool isValidFor(ReaderCloudNarrationSynthesisRequest request) {
    if (isEmpty ||
        startCharacter != request.startCharacter ||
        endCharacter <= startCharacter ||
        endCharacter != request.endCharacter) {
      return false;
    }

    return timingCues.every(
      (cue) =>
          cue.startCharacter >= startCharacter &&
          cue.endCharacter > cue.startCharacter &&
          cue.endCharacter <= endCharacter,
    );
  }
}

abstract interface class ReaderCloudNarrationProvider {
  String get key;
  String get displayName;
  ReaderCloudNarrationProviderCapabilities get capabilities;

  Future<ReaderCloudNarrationProviderStatus> checkStatus();

  Future<List<ReaderNarrationVoice>> loadVoices();

  Future<ReaderCloudNarrationAudioSegment> synthesize(
    ReaderCloudNarrationSynthesisRequest request,
  );
}

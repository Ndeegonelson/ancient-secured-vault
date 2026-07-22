import 'reader_cloud_narration_provider.dart';
import 'reader_narration_voice.dart';

class ReaderCloudNarrationTextSegment {
  const ReaderCloudNarrationTextSegment({
    required this.index,
    required this.text,
    required this.startCharacter,
    required this.endCharacter,
    required this.isFinal,
  });

  final int index;
  final String text;
  final int startCharacter;
  final int endCharacter;
  final bool isFinal;

  int get characterCount => endCharacter - startCharacter;

  bool containsCharacter(int characterOffset) {
    return characterOffset >= startCharacter && characterOffset < endCharacter;
  }

  ReaderCloudNarrationSynthesisRequest toSynthesisRequest({
    required ReaderNarrationVoice voice,
    required double rate,
  }) {
    return ReaderCloudNarrationSynthesisRequest(
      text: text,
      voice: voice,
      rate: rate,
      startCharacter: startCharacter,
    );
  }
}

class ReaderCloudNarrationTextPlanner {
  const ReaderCloudNarrationTextPlanner({
    this.maximumSegmentCharacters = 2400,
    this.preferredSegmentCharacters = 900,
  }) : assert(maximumSegmentCharacters > 0),
       assert(preferredSegmentCharacters > 0);

  final int maximumSegmentCharacters;
  final int preferredSegmentCharacters;

  List<ReaderCloudNarrationTextSegment> plan({
    required String text,
    int startCharacter = 0,
  }) {
    if (text.isEmpty) return const [];

    final safeStart = startCharacter.clamp(0, text.length);
    if (safeStart >= text.length) return const [];

    final segments = <ReaderCloudNarrationTextSegment>[];
    var segmentStart = safeStart;

    while (segmentStart < text.length) {
      final hardEnd = (segmentStart + maximumSegmentCharacters).clamp(
        segmentStart,
        text.length,
      );
      final preferredEnd =
          (segmentStart +
                  preferredSegmentCharacters.clamp(1, maximumSegmentCharacters))
              .clamp(segmentStart, hardEnd);
      final segmentEnd = hardEnd >= text.length
          ? text.length
          : _preferredBoundary(
              text,
              segmentStart: segmentStart,
              preferredEnd: preferredEnd,
              hardEnd: hardEnd,
            );

      segments.add(
        ReaderCloudNarrationTextSegment(
          index: segments.length,
          text: text.substring(segmentStart, segmentEnd),
          startCharacter: segmentStart,
          endCharacter: segmentEnd,
          isFinal: segmentEnd == text.length,
        ),
      );
      segmentStart = segmentEnd;
    }

    return List.unmodifiable(segments);
  }

  int _preferredBoundary(
    String text, {
    required int segmentStart,
    required int preferredEnd,
    required int hardEnd,
  }) {
    final searchWindow = text.substring(segmentStart, hardEnd);
    final preferredLength = preferredEnd - segmentStart;

    // Prefer completing the current sentence, even when it continues beyond
    // the target chunk size. This avoids artificial pauses in ordinary prose.
    final forwardSentenceBoundary = _firstSentenceBoundaryAtOrAfter(
      searchWindow,
      preferredLength,
    );
    if (forwardSentenceBoundary > 0) {
      return segmentStart + forwardSentenceBoundary;
    }

    final paragraphBoundary = searchWindow
        .substring(0, preferredLength)
        .lastIndexOf('\n\n');
    if (paragraphBoundary >= (preferredLength * 0.5).floor()) {
      return segmentStart + paragraphBoundary + 2;
    }

    final sentenceBoundary = _lastSentenceBoundary(
      searchWindow.substring(0, preferredLength),
    );
    if (sentenceBoundary >= (preferredLength * 0.5).floor()) {
      return segmentStart + sentenceBoundary;
    }

    final whitespaceBoundary = searchWindow
        .substring(0, preferredLength)
        .lastIndexOf(RegExp(r'\s'));
    if (whitespaceBoundary >= (preferredLength * 0.5).floor()) {
      return segmentStart + whitespaceBoundary + 1;
    }

    return hardEnd;
  }

  int _lastSentenceBoundary(String text) {
    var boundary = -1;

    for (final match in RegExp(r'''[.!?]["')\]]*\s+''').allMatches(text)) {
      boundary = match.end;
    }

    return boundary;
  }

  int _firstSentenceBoundaryAtOrAfter(String text, int minimumLength) {
    for (final match in RegExp(r'''[.!?]["')\]]*\s+''').allMatches(text)) {
      if (match.end >= minimumLength) return match.end;
    }

    return -1;
  }
}

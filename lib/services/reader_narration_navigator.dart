enum ReaderNarrationDirection { backward, forward }

enum ReaderNarrationJumpKind { paragraph, section, pageEdge }

class ReaderNarrationJump {
  const ReaderNarrationJump({
    required this.offset,
    required this.kind,
    required this.repeatCount,
  });

  final int offset;
  final ReaderNarrationJumpKind kind;
  final int repeatCount;
}

class ReaderNarrationNavigator {
  static const Duration repeatWindow = Duration(seconds: 2);

  ReaderNarrationDirection? _lastDirection;
  DateTime? _lastJumpAt;
  int _repeatCount = 0;

  ReaderNarrationJump target({
    required String text,
    required int currentOffset,
    required ReaderNarrationDirection direction,
    DateTime? now,
  }) {
    final safeText = text.trim();
    final safeOffset = currentOffset.clamp(0, safeText.length);
    final timestamp = now ?? DateTime.now();
    final isRepeated =
        _lastDirection == direction &&
        _lastJumpAt != null &&
        timestamp.difference(_lastJumpAt!) <= repeatWindow;

    _repeatCount = isRepeated ? (_repeatCount + 1).clamp(1, 3) : 1;
    _lastDirection = direction;
    _lastJumpAt = timestamp;

    final kind = switch (_repeatCount) {
      1 => ReaderNarrationJumpKind.paragraph,
      2 => ReaderNarrationJumpKind.section,
      _ => ReaderNarrationJumpKind.pageEdge,
    };

    final candidates = switch (kind) {
      ReaderNarrationJumpKind.paragraph => _paragraphBoundaries(safeText),
      ReaderNarrationJumpKind.section => _sectionBoundaries(safeText),
      ReaderNarrationJumpKind.pageEdge => [0, safeText.length],
    };

    return ReaderNarrationJump(
      offset: _nearestBoundary(
        candidates,
        currentOffset: safeOffset,
        direction: direction,
        textLength: safeText.length,
      ),
      kind: kind,
      repeatCount: _repeatCount,
    );
  }

  List<int> _paragraphBoundaries(String text) {
    final boundaries = <int>{0, text.length};

    for (final match in RegExp(r'\n\s*\n+').allMatches(text)) {
      boundaries.add(match.end);
    }

    if (boundaries.length <= 2) {
      for (final match in RegExp(r'[.!?]\s+').allMatches(text)) {
        boundaries.add(match.end);
      }
    }

    return boundaries.toList()..sort();
  }

  List<int> _sectionBoundaries(String text) {
    final boundaries = <int>{0, text.length};
    var offset = 0;

    for (final line in text.split('\n')) {
      final trimmed = line.trim();

      if (_looksLikeHeading(trimmed)) {
        boundaries.add(offset + line.indexOf(trimmed));
      }

      offset += line.length + 1;
    }

    return boundaries.toList()..sort();
  }

  bool _looksLikeHeading(String line) {
    if (line.isEmpty || line.length > 100) return false;

    final lower = line.toLowerCase();
    if (RegExp(r'^(chapter|section|part|book)\b').hasMatch(lower)) {
      return true;
    }

    if (RegExp(r'^\d+(\.\d+)*[.)]?\s+\S+').hasMatch(line)) {
      return true;
    }

    final letters = line.replaceAll(RegExp(r'[^A-Za-z]'), '');
    return letters.length >= 4 &&
        letters == letters.toUpperCase() &&
        !RegExp(r'[.!?]$').hasMatch(line);
  }

  int _nearestBoundary(
    List<int> boundaries, {
    required int currentOffset,
    required ReaderNarrationDirection direction,
    required int textLength,
  }) {
    if (direction == ReaderNarrationDirection.backward) {
      for (final boundary in boundaries.reversed) {
        if (boundary < currentOffset - 1) return boundary;
      }

      return 0;
    }

    for (final boundary in boundaries) {
      if (boundary > currentOffset + 1) {
        return boundary >= textLength
            ? (textLength - 1).clamp(0, textLength)
            : boundary.clamp(0, textLength);
      }
    }

    return (textLength - 1).clamp(0, textLength);
  }
}

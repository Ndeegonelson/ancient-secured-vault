import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

class ReaderTextSelectionDialog extends StatefulWidget {
  const ReaderTextSelectionDialog({
    super.key,
    required this.pageNumber,
    required this.pageText,
    this.title,
    this.confirmLabel = 'Narrate Selection',
    this.confirmIcon = Icons.record_voice_over,
  });

  final int pageNumber;
  final Future<String> pageText;
  final String? title;
  final String confirmLabel;
  final IconData confirmIcon;

  @override
  State<ReaderTextSelectionDialog> createState() =>
      _ReaderTextSelectionDialogState();
}

class _ReaderTextSelectionDialogState extends State<ReaderTextSelectionDialog> {
  static const int _maximumPassageCharacters = 520;

  String _selectedText = '';
  int? _selectedPassageIndex;

  void _selectPassage(_SelectablePassage passage) {
    setState(() {
      _selectedText = passage.text;
      _selectedPassageIndex = passage.index;
    });
  }

  List<_SelectablePassage> _passagesFor(String text) {
    final blocks = text
        .split(RegExp(r'\n\s*\n+'))
        .map(_cleanPassage)
        .where((block) => block.isNotEmpty)
        .toList();
    final sourceBlocks = blocks.isEmpty ? [_cleanPassage(text)] : blocks;
    final passages = <_SelectablePassage>[];

    for (final block in sourceBlocks) {
      for (final chunk in _chunkPassage(block)) {
        passages.add(_SelectablePassage(index: passages.length, text: chunk));
      }
    }

    return passages;
  }

  List<String> _chunkPassage(String text) {
    if (text.length <= _maximumPassageCharacters) return [text];

    final chunks = <String>[];
    final sentences = RegExp(
      r'''[^.!?]+(?:[.!?]+["')\]]*)?\s*''',
    ).allMatches(text).map((match) => match.group(0)!.trim()).toList();
    final sourceSentences = sentences.isEmpty ? [text] : sentences;
    var current = '';

    for (final sentence in sourceSentences) {
      if (sentence.length > _maximumPassageCharacters) {
        if (current.isNotEmpty) {
          chunks.add(current);
          current = '';
        }
        chunks.addAll(_chunkLongText(sentence));
        continue;
      }

      final candidate = current.isEmpty ? sentence : '$current $sentence';
      if (candidate.length <= _maximumPassageCharacters) {
        current = candidate;
      } else {
        if (current.isNotEmpty) chunks.add(current);
        current = sentence;
      }
    }

    if (current.isNotEmpty) chunks.add(current);
    return chunks;
  }

  List<String> _chunkLongText(String text) {
    final chunks = <String>[];
    final words = text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
    var current = '';

    for (final word in words) {
      final candidate = current.isEmpty ? word : '$current $word';
      if (candidate.length <= _maximumPassageCharacters) {
        current = candidate;
      } else {
        if (current.isNotEmpty) chunks.add(current);
        current = word;
      }
    }

    if (current.isNotEmpty) chunks.add(current);
    return chunks;
  }

  String _cleanPassage(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: AlertDialog(
        backgroundColor: const Color(0xFF0F1117),
        title: Text(
          widget.title ?? 'Select Passage | Page ${widget.pageNumber}',
          style: const TextStyle(color: Colors.greenAccent),
        ),
        content: SizedBox(
          width: 620,
          height: 500,
          child: FutureBuilder<String>(
            future: widget.pageText,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  snapshot.error.toString(),
                  style: const TextStyle(color: Colors.redAccent),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.greenAccent),
                );
              }

              final text = snapshot.data!.trim();
              final passages = _passagesFor(text);

              if (text.isEmpty) {
                return const Center(
                  child: Text(
                    'No readable text was found on this page.',
                    style: TextStyle(color: Colors.orangeAccent),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedText.isEmpty
                        ? 'No passage selected'
                        : '${_selectedText.length} characters selected',
                    style: TextStyle(
                      color: _selectedText.isEmpty
                          ? Colors.white54
                          : Colors.greenAccent,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: passages.length,
                        separatorBuilder: (context, index) =>
                            const Divider(color: Colors.white10),
                        itemBuilder: (context, index) {
                          final passage = passages[index];
                          final isSelected =
                              _selectedPassageIndex == passage.index &&
                              _selectedText == passage.text;

                          return Material(
                            color: isSelected
                                ? Colors.greenAccent.withValues(alpha: 0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () => _selectPassage(passage),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.check_circle
                                          : Icons.ads_click,
                                      color: isSelected
                                          ? Colors.greenAccent
                                          : Colors.white38,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        passage.text,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 16,
                                          height: 1.45,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: _selectedText.isEmpty
                ? null
                : () => Navigator.pop(context, _selectedText),
            icon: Icon(widget.confirmIcon),
            label: Text(widget.confirmLabel),
          ),
        ],
      ),
    );
  }
}

class _SelectablePassage {
  const _SelectablePassage({required this.index, required this.text});

  final int index;
  final String text;
}

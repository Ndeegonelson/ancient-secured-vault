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
  String _selectedText = '';

  void _updateSelection(String text, TextSelection selection) {
    final start = selection.start.clamp(0, text.length);
    final end = selection.end.clamp(start, text.length);
    final selectedText = selection.isCollapsed
        ? ''
        : text.substring(start, end).trim();

    if (_selectedText == selectedText) return;

    setState(() {
      _selectedText = selectedText;
    });
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
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(
                          text,
                          onSelectionChanged: (selection, cause) {
                            _updateSelection(text, selection);
                          },
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
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

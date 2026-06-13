import 'package:ancient_secure_docs/services/reader_suggestion_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads suggestion data with safe defaults', () {
    final suggestion = ReaderSuggestion.fromMap({
      'userEmail': ' reader@example.com ',
      'message': ' Add offline reading. ',
      'status': 'reviewing',
      'source': ' reader_dashboard ',
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(1000),
    }, id: 'suggestion-1');

    expect(suggestion.id, 'suggestion-1');
    expect(suggestion.userEmail, 'reader@example.com');
    expect(suggestion.message, 'Add offline reading.');
    expect(suggestion.status, ReaderSuggestionStatus.reviewing);
    expect(suggestion.source, 'reader_dashboard');
    expect(suggestion.hasMessage, isTrue);
  });

  test('sorts suggestions newest first and ignores empty messages', () {
    final older = ReaderSuggestion.fromMap({
      'message': 'Older idea',
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(1000),
    }, id: 'older');
    final newer = ReaderSuggestion.fromMap({
      'message': 'Newer idea',
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(3000),
    }, id: 'newer');
    final empty = ReaderSuggestion.fromMap({
      'message': '   ',
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(5000),
    }, id: 'empty');

    final sorted = ReaderSuggestion.sortNewest([older, empty, newer]);

    expect(sorted.map((item) => item.id), ['newer', 'older']);
  });

  test('builds suggestion payloads and labels statuses', () {
    final draft = ReaderSuggestionDraft(
      userEmail: ' reader@example.com ',
      message: ' Add achievements for completed books. ',
      source: ' dashboard ',
    );

    expect(draft.toFirestore(createdAt: 'now'), {
      'userEmail': 'reader@example.com',
      'message': 'Add achievements for completed books.',
      'source': 'dashboard',
      'status': 'open',
      'createdAt': 'now',
    });
    expect(readReaderSuggestionStatus('done'), ReaderSuggestionStatus.resolved);
    expect(
      readerSuggestionStatusKey(ReaderSuggestionStatus.archived),
      'archived',
    );
    expect(
      readerSuggestionStatusLabel(ReaderSuggestionStatus.reviewing),
      'Reviewing',
    );
  });
}

import 'package:ancient_secure_docs/services/reader_cloud_narration_text_planner.dart';
import 'package:ancient_secure_docs/services/reader_narration_voice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty or completed text produces no cloud narration segments', () {
    const planner = ReaderCloudNarrationTextPlanner();

    expect(planner.plan(text: ''), isEmpty);
    expect(planner.plan(text: 'Complete', startCharacter: 8), isEmpty);
  });

  test('long document segments preserve every original character', () {
    const planner = ReaderCloudNarrationTextPlanner(
      maximumSegmentCharacters: 40,
    );
    const text =
        'First paragraph contains useful context.\n\n'
        'Second paragraph continues the lesson with more detail.\n\n'
        'Final paragraph closes the document.';

    final segments = planner.plan(text: text);

    expect(segments.length, greaterThan(1));
    expect(segments.map((segment) => segment.text).join(), text);
    expect(segments.every((segment) => segment.characterCount <= 40), isTrue);
    expect(segments.first.startCharacter, 0);
    expect(segments.last.endCharacter, text.length);
    expect(segments.last.isFinal, isTrue);
  });

  test('planner prefers a nearby paragraph boundary', () {
    const planner = ReaderCloudNarrationTextPlanner(
      maximumSegmentCharacters: 45,
    );
    const text =
        'Opening paragraph is complete here.\n\n'
        'The next paragraph contains additional narration content.';

    final segments = planner.plan(text: text);

    expect(segments.first.text, 'Opening paragraph is complete here.\n\n');
    expect(segments[1].startCharacter, segments.first.endCharacter);
  });

  test('planner resumes from the exact stored character offset', () {
    const planner = ReaderCloudNarrationTextPlanner(
      maximumSegmentCharacters: 30,
    );
    const text =
        'Earlier narration content. Resume narration from this sentence.';
    final resumeOffset = text.indexOf('Resume');

    final segments = planner.plan(text: text, startCharacter: resumeOffset);

    expect(segments.first.startCharacter, resumeOffset);
    expect(
      segments.map((segment) => segment.text).join(),
      text.substring(resumeOffset),
    );
    expect(segments.first.containsCharacter(resumeOffset), isTrue);
    expect(segments.first.containsCharacter(resumeOffset - 1), isFalse);
  });

  test('unusually long words safely use the hard provider limit', () {
    const planner = ReaderCloudNarrationTextPlanner(
      maximumSegmentCharacters: 10,
    );
    const text = 'averylongwordwithoutspaces';

    final segments = planner.plan(text: text);

    expect(segments.map((segment) => segment.text).join(), text);
    expect(segments.every((segment) => segment.characterCount <= 10), isTrue);
  });

  test('segment creates a synthesis request with its absolute position', () {
    const planner = ReaderCloudNarrationTextPlanner(
      maximumSegmentCharacters: 20,
    );
    const voice = ReaderNarrationVoice(
      name: 'Ama',
      locale: 'en-GH',
      provider: ReaderNarrationVoiceProvider.cloudAi,
      providerKey: 'future-provider',
    );
    const text = 'Skip this. Narrate this cloud segment.';
    final startCharacter = text.indexOf('Narrate');

    final segment = planner
        .plan(text: text, startCharacter: startCharacter)
        .first;
    final request = segment.toSynthesisRequest(voice: voice, rate: 0.8);

    expect(request.text, segment.text);
    expect(request.startCharacter, startCharacter);
    expect(request.voice, voice);
    expect(request.rate, 0.8);
  });
}

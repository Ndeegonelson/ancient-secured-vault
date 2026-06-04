import 'package:ancient_secure_docs/services/reader_narration_voice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads browser voice details and builds a stable identifier', () {
    final voice = ReaderNarrationVoice.fromMap({
      'name': 'Premium Voice',
      'locale': 'en-GH',
      'gender': 'Female',
    });

    expect(voice.id, 'browser|en-GH|Premium Voice');
    expect(voice.label, 'Premium Voice | en-GH | Female');
    expect(voice.supportsBaseLocale('en-US'), isTrue);
    expect(voice.supportsBaseLocale('fr-FR'), isFalse);
    expect(voice.browserVoice, {'name': 'Premium Voice', 'locale': 'en-GH'});
  });

  test('reserves cloud AI as a separate future voice provider', () {
    const voice = ReaderNarrationVoice(
      name: 'Future African Narrator',
      locale: 'fr-GH',
      provider: ReaderNarrationVoiceProvider.cloudAi,
    );

    expect(voice.id, 'cloudAi|fr-GH|Future African Narrator');
  });

  test('recognizes rediscovered browser voices as the same dropdown value', () {
    const firstDiscovery = ReaderNarrationVoice(
      name: 'Microsoft Mark',
      locale: 'en-US',
    );
    const secondDiscovery = ReaderNarrationVoice(
      name: 'Microsoft Mark',
      locale: 'en-US',
    );

    expect(firstDiscovery, secondDiscovery);
    final rediscoveredVoices = <ReaderNarrationVoice>{firstDiscovery};
    rediscoveredVoices.add(secondDiscovery);
    expect(rediscoveredVoices, hasLength(1));
  });
}

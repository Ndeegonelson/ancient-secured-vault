enum ReaderNarrationVoiceProvider { browser, cloudAi }

class ReaderNarrationVoice {
  const ReaderNarrationVoice({
    required this.name,
    required this.locale,
    this.gender,
    this.provider = ReaderNarrationVoiceProvider.browser,
  });

  factory ReaderNarrationVoice.fromMap(Map<dynamic, dynamic> data) {
    return ReaderNarrationVoice(
      name: data['name']?.toString() ?? '',
      locale: data['locale']?.toString() ?? '',
      gender: data['gender']?.toString(),
    );
  }

  final String name;
  final String locale;
  final String? gender;
  final ReaderNarrationVoiceProvider provider;

  String get id => '${provider.name}|$locale|$name';
  String get baseLocale => locale.split('-').first.toLowerCase();

  String get label {
    final normalizedGender = gender?.trim();
    final genderLabel = normalizedGender == null || normalizedGender.isEmpty
        ? ''
        : ' | $normalizedGender';

    return '$name | $locale$genderLabel';
  }

  bool supportsBaseLocale(String locale) {
    return baseLocale == locale.split('-').first.toLowerCase();
  }

  Map<String, String> get browserVoice => {'name': name, 'locale': locale};

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ReaderNarrationVoice && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

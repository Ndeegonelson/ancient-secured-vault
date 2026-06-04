enum ReaderNarrationVoiceProvider { browser, cloudAi }

class ReaderNarrationVoice {
  const ReaderNarrationVoice({
    required this.name,
    required this.locale,
    this.gender,
    this.accent,
    this.style,
    this.providerKey,
    this.isCustom = false,
    this.provider = ReaderNarrationVoiceProvider.browser,
  });

  factory ReaderNarrationVoice.fromMap(Map<dynamic, dynamic> data) {
    return ReaderNarrationVoice(
      name: data['name']?.toString() ?? '',
      locale: data['locale']?.toString() ?? '',
      gender: data['gender']?.toString(),
      accent: data['accent']?.toString(),
      style: data['style']?.toString(),
      providerKey: data['providerKey']?.toString(),
      isCustom: data['isCustom'] == true,
    );
  }

  final String name;
  final String locale;
  final String? gender;
  final String? accent;
  final String? style;
  final String? providerKey;
  final bool isCustom;
  final ReaderNarrationVoiceProvider provider;

  String get id {
    final normalizedProviderKey = providerKey?.trim();
    final providerPrefix =
        normalizedProviderKey == null || normalizedProviderKey.isEmpty
        ? provider.name
        : '${provider.name}|$normalizedProviderKey';

    return '$providerPrefix|$locale|$name';
  }

  String get baseLocale => locale.split('-').first.toLowerCase();

  String get label {
    final normalizedGender = gender?.trim();
    final normalizedAccent = accent?.trim();
    final normalizedStyle = style?.trim();
    final genderLabel = normalizedGender == null || normalizedGender.isEmpty
        ? ''
        : ' | $normalizedGender';
    final accentLabel = normalizedAccent == null || normalizedAccent.isEmpty
        ? ''
        : ' | $normalizedAccent';
    final styleLabel = normalizedStyle == null || normalizedStyle.isEmpty
        ? ''
        : ' | $normalizedStyle';
    final customLabel = isCustom ? ' | Custom' : '';

    return '$name | $locale$accentLabel$genderLabel$styleLabel$customLabel';
  }

  bool supportsBaseLocale(String locale) {
    return baseLocale == locale.split('-').first.toLowerCase();
  }

  Map<String, String> get browserVoice => {'name': name, 'locale': locale};

  ReaderNarrationVoice copyWith({
    String? name,
    String? locale,
    String? gender,
    String? accent,
    String? style,
    String? providerKey,
    bool? isCustom,
    ReaderNarrationVoiceProvider? provider,
  }) {
    return ReaderNarrationVoice(
      name: name ?? this.name,
      locale: locale ?? this.locale,
      gender: gender ?? this.gender,
      accent: accent ?? this.accent,
      style: style ?? this.style,
      providerKey: providerKey ?? this.providerKey,
      isCustom: isCustom ?? this.isCustom,
      provider: provider ?? this.provider,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ReaderNarrationVoice && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

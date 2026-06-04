import 'dart:convert';
import 'dart:typed_data';

import 'reader_cloud_narration_provider.dart';
import 'reader_narration_voice.dart';

abstract interface class ReaderCloudNarrationCallableClient {
  Future<Map<String, dynamic>> call(
    String functionName,
    Map<String, dynamic> data,
  );
}

class ReaderCloudNarrationCallableReadiness {
  const ReaderCloudNarrationCallableReadiness.ready({
    this.message = 'Secure cloud narration is ready.',
  }) : isReady = true;

  const ReaderCloudNarrationCallableReadiness.unavailable({
    required this.message,
  }) : isReady = false;

  final bool isReady;
  final String message;
}

abstract interface class ReaderCloudNarrationCallableReadinessClient {
  Future<ReaderCloudNarrationCallableReadiness> checkReadiness();
}

class ReaderCloudNarrationCallableProvider
    implements ReaderCloudNarrationProvider {
  const ReaderCloudNarrationCallableProvider({
    required this.client,
    this.providerKey = 'firebase-functions',
    this.providerName = 'Secure Cloud Narration',
  });

  final ReaderCloudNarrationCallableClient client;
  final String providerKey;
  final String providerName;

  @override
  String get key => providerKey;

  @override
  String get displayName => providerName;

  @override
  ReaderCloudNarrationProviderCapabilities get capabilities =>
      const ReaderCloudNarrationProviderCapabilities(
        supportsStreamingAudio: false,
        supportsWordTimings: true,
        supportsVoiceStyles: true,
        supportsCustomVoices: true,
      );

  @override
  Future<ReaderCloudNarrationProviderStatus> checkStatus() async {
    if (client is ReaderCloudNarrationCallableReadinessClient) {
      final readinessClient =
          client as ReaderCloudNarrationCallableReadinessClient;
      final readiness = await readinessClient.checkReadiness();
      if (!readiness.isReady) {
        return ReaderCloudNarrationProviderStatus(
          state: ReaderCloudNarrationProviderState.temporarilyUnavailable,
          message: readiness.message,
        );
      }
    }

    return ReaderCloudNarrationProviderStatus(
      state: ReaderCloudNarrationProviderState.ready,
      message: '$providerName is ready.',
    );
  }

  @override
  Future<List<ReaderNarrationVoice>> loadVoices() async {
    final response = await client.call('cloudNarrationCatalog', const {});
    final status = response['status']?.toString();
    if (status == 'notConfigured') return const [];
    if (status != 'ready') {
      throw StateError('Cloud narration catalog is not ready.');
    }

    final voices = response['voices'];
    if (voices is! List) {
      throw StateError('Cloud narration catalog is invalid.');
    }

    return voices.map(_voiceFromResponse).toList(growable: false);
  }

  ReaderNarrationVoice _voiceFromResponse(dynamic value) {
    if (value is! Map) {
      throw StateError('Cloud narration voice is invalid.');
    }

    final cloudVoiceId = _requiredString(value['id'], 'voice id');
    return ReaderNarrationVoice(
      name: _requiredString(value['name'], 'voice name'),
      locale: _requiredString(value['locale'], 'voice locale'),
      gender: _optionalString(value['gender']),
      accent: _optionalString(value['accent']),
      style: _optionalString(value['style']),
      cloudVoiceId: cloudVoiceId,
      isCustom: value['isCustom'] == true,
      provider: ReaderNarrationVoiceProvider.cloudAi,
      providerKey: providerKey,
    );
  }

  @override
  Future<ReaderCloudNarrationAudioSegment> synthesize(
    ReaderCloudNarrationSynthesisRequest request,
  ) async {
    final cloudVoiceId = request.voice.cloudVoiceId?.trim();
    if (cloudVoiceId == null || cloudVoiceId.isEmpty) {
      throw StateError('The selected cloud narrator is missing its server id.');
    }

    final response = await client.call('synthesizeCloudNarration', {
      'text': request.text,
      'voiceId': cloudVoiceId,
      'rate': request.rate,
      'startCharacter': request.startCharacter,
    });

    return _audioSegmentFromResponse(response);
  }

  ReaderCloudNarrationAudioSegment _audioSegmentFromResponse(
    Map<String, dynamic> response,
  ) {
    final audioBase64 = _requiredString(response['audioBase64'], 'audio data');
    final audioBytes = _decodeAudio(audioBase64);
    final contentType = _requiredString(
      response['contentType'],
      'content type',
    );
    final startCharacter = _requiredInt(
      response['startCharacter'],
      'start character',
    );
    final endCharacter = _requiredInt(
      response['endCharacter'],
      'end character',
    );
    final durationMilliseconds = response['durationMilliseconds'];

    return ReaderCloudNarrationAudioSegment(
      audioBytes: audioBytes,
      contentType: contentType,
      startCharacter: startCharacter,
      endCharacter: endCharacter,
      duration: durationMilliseconds is int
          ? Duration(milliseconds: durationMilliseconds)
          : null,
      timingCues: _timingCuesFromResponse(response['timingCues']),
      usage: _usageFromResponse(response['usage']),
    );
  }

  ReaderCloudNarrationUsage? _usageFromResponse(dynamic value) {
    if (value == null) return null;
    if (value is! Map) {
      throw StateError('Cloud narration usage data is invalid.');
    }

    return ReaderCloudNarrationUsage(
      dateKey: _optionalString(value['dateKey']),
      plan: _optionalString(value['plan']),
      usedCharacters: _optionalInt(value['usedCharacters']),
      usedRequests: _optionalInt(value['usedRequests']),
      remainingCharacters: _optionalInt(value['remainingCharacters']),
      remainingRequests: _optionalInt(value['remainingRequests']),
    );
  }

  List<ReaderCloudNarrationTimingCue> _timingCuesFromResponse(dynamic value) {
    if (value == null) return const [];
    if (value is! List) {
      throw StateError('Cloud narration timing data is invalid.');
    }

    return value
        .map((cue) {
          if (cue is! Map) {
            throw StateError('Cloud narration timing cue is invalid.');
          }

          return ReaderCloudNarrationTimingCue(
            startCharacter: _requiredInt(cue['startCharacter'], 'cue start'),
            endCharacter: _requiredInt(cue['endCharacter'], 'cue end'),
            audioOffset: Duration(
              milliseconds: _requiredInt(
                cue['audioOffsetMilliseconds'],
                'cue audio offset',
              ),
            ),
          );
        })
        .toList(growable: false);
  }

  Uint8List _decodeAudio(String audioBase64) {
    try {
      return Uint8List.fromList(base64Decode(audioBase64));
    } on FormatException {
      throw StateError('Cloud narration audio data is invalid.');
    }
  }

  String _requiredString(dynamic value, String label) {
    if (value is! String || value.trim().isEmpty) {
      throw StateError('Cloud narration $label is missing.');
    }

    return value.trim();
  }

  String? _optionalString(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  int? _optionalInt(dynamic value) {
    if (value is! int || value < 0) return null;
    return value;
  }

  int _requiredInt(dynamic value, String label) {
    if (value is! int) {
      throw StateError('Cloud narration $label is missing.');
    }

    return value;
  }
}

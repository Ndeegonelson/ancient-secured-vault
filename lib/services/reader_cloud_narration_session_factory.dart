import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

import 'reader_cloud_narration_audio_player.dart';
import 'reader_cloud_narration_audio_player_factory.dart';
import 'reader_cloud_narration_callable_provider.dart';
import 'reader_cloud_narration_http_callable_client.dart';
import 'reader_cloud_narration_playback_controller.dart';
import 'reader_cloud_narration_preparation_queue.dart';
import 'reader_cloud_narration_registry.dart';
import 'reader_cloud_narration_session_coordinator.dart';
import 'reader_cloud_narration_text_planner.dart';
import 'reader_narration_access_policy.dart';

typedef ReaderCloudNarrationAudioPlayerBuilder =
    ReaderCloudNarrationAudioPlayer Function();

class ReaderCloudNarrationSessionFactory {
  ReaderCloudNarrationSessionFactory({
    required this.client,
    ReaderCloudNarrationAudioPlayerBuilder? audioPlayerBuilder,
    this.providerKey = 'firebase-functions',
    this.providerName = 'Secure Cloud Narration',
    this.textPlanner = const ReaderCloudNarrationTextPlanner(),
    this.maximumBufferedSegments = 2,
    this.maximumBufferedAudioBytes = 8 * 1024 * 1024,
  }) : audioPlayerBuilder =
           audioPlayerBuilder ?? createReaderCloudNarrationAudioPlayer;

  factory ReaderCloudNarrationSessionFactory.firebase({
    required FirebaseOptions options,
    FirebaseAuth? auth,
    ReaderCloudNarrationTokenProvider? appCheckTokenProvider,
    bool requiresAppCheckToken = true,
    String region = 'us-central1',
    http.Client? httpClient,
    Uri? originOverride,
    ReaderCloudNarrationAudioPlayerBuilder? audioPlayerBuilder,
    String providerKey = 'firebase-functions',
    String providerName = 'Secure Cloud Narration',
    ReaderCloudNarrationTextPlanner textPlanner =
        const ReaderCloudNarrationTextPlanner(),
    int maximumBufferedSegments = 2,
    int maximumBufferedAudioBytes = 8 * 1024 * 1024,
  }) {
    return ReaderCloudNarrationSessionFactory(
      client: ReaderCloudNarrationHttpCallableClient.firebase(
        options: options,
        auth: auth,
        appCheckTokenProvider: appCheckTokenProvider,
        requiresAppCheckToken: requiresAppCheckToken,
        region: region,
        httpClient: httpClient,
        originOverride: originOverride,
      ),
      audioPlayerBuilder: audioPlayerBuilder,
      providerKey: providerKey,
      providerName: providerName,
      textPlanner: textPlanner,
      maximumBufferedSegments: maximumBufferedSegments,
      maximumBufferedAudioBytes: maximumBufferedAudioBytes,
    );
  }

  final ReaderCloudNarrationCallableClient client;
  final ReaderCloudNarrationAudioPlayerBuilder audioPlayerBuilder;
  final String providerKey;
  final String providerName;
  final ReaderCloudNarrationTextPlanner textPlanner;
  final int maximumBufferedSegments;
  final int maximumBufferedAudioBytes;

  ReaderCloudNarrationSessionCoordinator createCoordinator({
    required ReaderNarrationAccessPolicy accessPolicy,
  }) {
    final registry = createRegistry();
    final queue = ReaderCloudNarrationPreparationQueue(
      registry: registry,
      planner: textPlanner,
      maximumBufferedSegments: maximumBufferedSegments,
      maximumBufferedAudioBytes: maximumBufferedAudioBytes,
    );
    final playbackController = ReaderCloudNarrationPlaybackController(
      queue: queue,
      audioPlayer: audioPlayerBuilder(),
    );

    return ReaderCloudNarrationSessionCoordinator(
      registry: registry,
      playbackController: playbackController,
      accessPolicy: accessPolicy,
    );
  }

  ReaderCloudNarrationRegistry createRegistry() {
    return ReaderCloudNarrationRegistry(
      providers: [
        ReaderCloudNarrationCallableProvider(
          client: client,
          providerKey: providerKey,
          providerName: providerName,
        ),
      ],
    );
  }
}

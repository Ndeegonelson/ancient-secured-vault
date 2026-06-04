import 'reader_cloud_narration_audio_player.dart';
import 'reader_temporary_audio_platform_stub.dart'
    if (dart.library.html) 'reader_temporary_audio_platform_web.dart'
    as platform_factory;
import 'reader_temporary_cloud_narration_audio_player.dart';

ReaderCloudNarrationAudioPlayer createReaderCloudNarrationAudioPlayer() {
  return ReaderTemporaryCloudNarrationAudioPlayer(
    platform: platform_factory.createReaderTemporaryAudioPlatform(),
  );
}

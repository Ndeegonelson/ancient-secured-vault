import 'dart:async';

import 'package:flutter/foundation.dart';

import 'reader_cloud_narration_playback_controller.dart';
import 'reader_cloud_narration_provider.dart';
import 'reader_cloud_narration_registry.dart';
import 'reader_narration_access_policy.dart';
import 'reader_narration_voice.dart';

enum ReaderCloudNarrationSessionState {
  idle,
  loadingCatalog,
  ready,
  preparing,
  playing,
  paused,
  stopped,
  completed,
  unavailable,
  accessDenied,
  error,
}

class ReaderCloudNarrationSessionCoordinator extends ChangeNotifier {
  ReaderCloudNarrationSessionCoordinator({
    required this.registry,
    required this.playbackController,
    required ReaderNarrationAccessPolicy accessPolicy,
    // ignore: prefer_initializing_formals
  }) : _accessPolicy = accessPolicy {
    playbackController.addListener(_handlePlaybackChange);
  }

  final ReaderCloudNarrationRegistry registry;
  final ReaderCloudNarrationPlaybackController playbackController;

  ReaderNarrationAccessPolicy _accessPolicy;
  ReaderCloudNarrationCatalog? _catalog;
  ReaderNarrationVoice? _selectedVoice;
  ReaderCloudNarrationSessionState _state =
      ReaderCloudNarrationSessionState.idle;
  String? _errorMessage;
  int _catalogRequestId = 0;
  int _voiceSelectionRequestId = 0;
  bool _disposed = false;

  ReaderNarrationAccessPolicy get accessPolicy => _accessPolicy;
  ReaderCloudNarrationCatalog? get catalog => _catalog;
  ReaderNarrationVoice? get selectedVoice => _selectedVoice;
  ReaderCloudNarrationSessionState get state => _state;
  String? get errorMessage => _errorMessage;
  List<ReaderNarrationVoice> get availableVoices =>
      _catalog?.voices ?? const [];
  Map<String, ReaderCloudNarrationProviderStatus> get providerStatuses =>
      _catalog?.providerStatuses ?? const {};
  bool get hasCloudAccess => _accessPolicy.canUseCloudNarration;
  bool get hasReadyProvider => _catalog?.hasReadyProvider ?? false;
  int get currentCharacterStart => playbackController.currentCharacterStart;
  int get currentCharacterEnd => playbackController.currentCharacterEnd;
  int get progressPercent => playbackController.progressPercent;

  List<ReaderNarrationVoice> voicesForLocale(String locale) {
    return availableVoices
        .where((voice) => voice.supportsBaseLocale(locale))
        .toList(growable: false);
  }

  Future<bool> refreshCatalog() async {
    if (!hasCloudAccess) {
      await _denyAccess();
      return false;
    }

    final requestId = ++_catalogRequestId;
    _state = ReaderCloudNarrationSessionState.loadingCatalog;
    _errorMessage = null;
    _notifyListeners();

    try {
      final catalog = await registry.loadCatalog();
      if (_disposed || requestId != _catalogRequestId || !hasCloudAccess) {
        return false;
      }

      _catalog = catalog;
      final selectedVoice = _selectedVoice;
      if (selectedVoice != null &&
          !catalog.voices.any((voice) => voice.id == selectedVoice.id)) {
        _selectedVoice = null;
        await playbackController.stop();
      }

      _state = catalog.hasReadyProvider && catalog.voices.isNotEmpty
          ? ReaderCloudNarrationSessionState.ready
          : ReaderCloudNarrationSessionState.unavailable;
      _notifyListeners();
      return _state == ReaderCloudNarrationSessionState.ready;
    } catch (error) {
      if (_disposed || requestId != _catalogRequestId || !hasCloudAccess) {
        return false;
      }

      _setError(_friendlyErrorMessage(error));
      return false;
    }
  }

  Future<bool> selectVoice(ReaderNarrationVoice voice) async {
    if (!hasCloudAccess) {
      await _denyAccess();
      return false;
    }

    final matchingVoice = availableVoices.where(
      (availableVoice) => availableVoice.id == voice.id,
    );
    if (voice.provider != ReaderNarrationVoiceProvider.cloudAi ||
        matchingVoice.isEmpty) {
      _setError('This cloud narration voice is not currently available.');
      return false;
    }

    if (_selectedVoice?.id == voice.id) return true;

    final requestId = ++_voiceSelectionRequestId;
    await playbackController.stop();
    if (_disposed || requestId != _voiceSelectionRequestId || !hasCloudAccess) {
      return false;
    }

    final currentMatchingVoice = availableVoices.where(
      (availableVoice) => availableVoice.id == voice.id,
    );
    if (currentMatchingVoice.isEmpty) {
      _setError('This cloud narration voice is no longer available.');
      return false;
    }

    _selectedVoice = currentMatchingVoice.first;
    _errorMessage = null;
    _state = ReaderCloudNarrationSessionState.ready;
    _notifyListeners();
    return true;
  }

  Future<bool> start({
    required String text,
    required double rate,
    int startCharacter = 0,
  }) async {
    if (!hasCloudAccess) {
      await _denyAccess();
      return false;
    }

    final voice = _selectedVoice;
    if (voice == null) {
      _setError('Choose a cloud narrator before starting narration.');
      return false;
    }
    if (!availableVoices.any(
      (availableVoice) => availableVoice.id == voice.id,
    )) {
      _setError('The selected cloud narrator is no longer available.');
      return false;
    }
    if (text.trim().isEmpty) {
      _setError('No readable text is available for cloud narration.');
      return false;
    }

    _errorMessage = null;
    _state = ReaderCloudNarrationSessionState.preparing;
    _notifyListeners();

    final started = await playbackController.start(
      text: text,
      voice: voice,
      rate: rate,
      startCharacter: startCharacter,
    );
    if (_disposed) return false;

    if (!started && playbackController.errorMessage != null) {
      _setError(playbackController.errorMessage!);
    }
    return started;
  }

  Future<void> pause() async {
    if (!hasCloudAccess) {
      await _denyAccess();
      return;
    }
    await playbackController.pause();
  }

  Future<void> resume() async {
    if (!hasCloudAccess) {
      await _denyAccess();
      return;
    }
    await playbackController.resume();
  }

  Future<void> stop() async {
    await playbackController.stop();
    if (_disposed) return;

    _errorMessage = null;
    _state = hasCloudAccess
        ? ReaderCloudNarrationSessionState.stopped
        : ReaderCloudNarrationSessionState.accessDenied;
    _notifyListeners();
  }

  Future<void> updateAccessPolicy(
    ReaderNarrationAccessPolicy accessPolicy,
  ) async {
    _accessPolicy = accessPolicy;
    if (!hasCloudAccess) {
      await _denyAccess();
      return;
    }

    _errorMessage = null;
    _state = _stateAfterAccessUpdate();
    _notifyListeners();
  }

  Future<void> _denyAccess() async {
    _catalogRequestId++;
    _voiceSelectionRequestId++;
    await playbackController.stop();
    if (_disposed) return;

    _selectedVoice = null;
    _catalog = null;
    _errorMessage = _accessPolicy.cloudUpgradeMessage;
    _state = ReaderCloudNarrationSessionState.accessDenied;
    _notifyListeners();
  }

  void _handlePlaybackChange() {
    if (_disposed) return;

    final playbackError = playbackController.errorMessage;
    if (playbackError != null) {
      _setError(playbackError);
      return;
    }

    _state = switch (playbackController.state) {
      ReaderCloudNarrationPlaybackState.idle =>
        ReaderCloudNarrationSessionState.idle,
      ReaderCloudNarrationPlaybackState.preparing =>
        ReaderCloudNarrationSessionState.preparing,
      ReaderCloudNarrationPlaybackState.playing =>
        ReaderCloudNarrationSessionState.playing,
      ReaderCloudNarrationPlaybackState.paused =>
        ReaderCloudNarrationSessionState.paused,
      ReaderCloudNarrationPlaybackState.stopped =>
        ReaderCloudNarrationSessionState.stopped,
      ReaderCloudNarrationPlaybackState.completed =>
        ReaderCloudNarrationSessionState.completed,
      ReaderCloudNarrationPlaybackState.error =>
        ReaderCloudNarrationSessionState.error,
    };
    _notifyListeners();
  }

  void _setError(String message) {
    if (_disposed) return;

    _errorMessage = _friendlyErrorMessage(message);
    _state = ReaderCloudNarrationSessionState.error;
    _notifyListeners();
  }

  ReaderCloudNarrationSessionState _stateAfterAccessUpdate() {
    if (_state == ReaderCloudNarrationSessionState.loadingCatalog) {
      return ReaderCloudNarrationSessionState.loadingCatalog;
    }

    return switch (playbackController.state) {
      ReaderCloudNarrationPlaybackState.preparing =>
        ReaderCloudNarrationSessionState.preparing,
      ReaderCloudNarrationPlaybackState.playing =>
        ReaderCloudNarrationSessionState.playing,
      ReaderCloudNarrationPlaybackState.paused =>
        ReaderCloudNarrationSessionState.paused,
      ReaderCloudNarrationPlaybackState.completed =>
        ReaderCloudNarrationSessionState.completed,
      ReaderCloudNarrationPlaybackState.error =>
        ReaderCloudNarrationSessionState.error,
      ReaderCloudNarrationPlaybackState.idle ||
      ReaderCloudNarrationPlaybackState.stopped =>
        _catalog == null
            ? ReaderCloudNarrationSessionState.idle
            : hasReadyProvider && availableVoices.isNotEmpty
            ? ReaderCloudNarrationSessionState.ready
            : ReaderCloudNarrationSessionState.unavailable,
    };
  }

  String _friendlyErrorMessage(Object error) {
    final message = error.toString().replaceFirst('Bad state: ', '').trim();
    return message.isEmpty
        ? 'Cloud narration is temporarily unavailable.'
        : message;
  }

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;

    _disposed = true;
    _catalogRequestId++;
    _voiceSelectionRequestId++;
    playbackController.removeListener(_handlePlaybackChange);
    unawaited(playbackController.stop());
    playbackController.dispose();
    super.dispose();
  }
}

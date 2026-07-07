import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:webview_flutter/webview_flutter.dart';

const _vaultUrl = 'https://vault.ancientsociety.tech/';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const AncientSecureVaultMobileApp());
}

class AncientSecureVaultMobileApp extends StatelessWidget {
  const AncientSecureVaultMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ANCIENT SECURED VAULT',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF63F5A5),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF10131A),
        useMaterial3: true,
      ),
      home: const VaultWebViewScreen(),
    );
  }
}

class VaultWebViewScreen extends StatefulWidget {
  const VaultWebViewScreen({super.key});

  @override
  State<VaultWebViewScreen> createState() => _VaultWebViewScreenState();
}

class _VaultWebViewScreenState extends State<VaultWebViewScreen> {
  late final WebViewController controller;
  final FlutterTts nativeTts = FlutterTts();
  var loadProgress = 0;
  String? loadError;
  String? activeUtteranceId;
  String activeUtteranceText = '';
  int activeUtteranceOffset = 0;
  Timer? estimatedProgressTimer;
  Timer? launchSplashTimer;
  bool showLaunchSplash = true;

  @override
  void initState() {
    super.initState();
    configureNativeTtsBridge();
    launchSplashTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {
        showLaunchSplash = false;
      });
    });
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('AncientSecureVaultAndroidApp/1.0')
      ..enableZoom(false)
      ..addJavaScriptChannel(
        'AncientVaultTts',
        onMessageReceived: handleNativeTtsMessage,
      )
      ..setBackgroundColor(const Color(0xFF10131A))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              loadProgress = progress;
              if (progress > 10) loadError = null;
            });
          },
          onPageFinished: (_) => lockMobileWebViewZoom(),
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame == false) return;
            setState(() {
              loadError = error.description;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(_vaultUrl));
  }

  Future<void> lockMobileWebViewZoom() async {
    try {
      await controller.enableZoom(false);
      await controller.runJavaScript(r'''
        (function () {
          var viewport = document.querySelector('meta[name="viewport"]');
          if (!viewport) {
            viewport = document.createElement('meta');
            viewport.name = 'viewport';
            document.head.appendChild(viewport);
          }
          viewport.setAttribute(
            'content',
            'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no'
          );
          document.documentElement.style.touchAction = 'auto';
          document.body.style.touchAction = 'auto';
        })();
      ''');
    } catch (_) {}
  }

  void configureNativeTtsBridge() {
    nativeTts.awaitSpeakCompletion(false);
    nativeTts.setVolume(1.0);
    nativeTts.setPitch(1.0);

    nativeTts.setStartHandler(() {
      emitNativeTtsEvent({'type': 'start'});
    });
    nativeTts.setCompletionHandler(() {
      estimatedProgressTimer?.cancel();
      emitNativeTtsEvent({'type': 'end'});
    });
    nativeTts.setPauseHandler(() {
      estimatedProgressTimer?.cancel();
      emitNativeTtsEvent({'type': 'pause'});
    });
    nativeTts.setContinueHandler(() {
      emitNativeTtsEvent({'type': 'resume'});
    });
    nativeTts.setCancelHandler(() {
      estimatedProgressTimer?.cancel();
      emitNativeTtsEvent({'type': 'cancel'});
    });
    nativeTts.setErrorHandler((message) {
      estimatedProgressTimer?.cancel();
      emitNativeTtsEvent({'type': 'error', 'error': message.toString()});
    });
    nativeTts.setProgressHandler((text, start, end, word) {
      activeUtteranceOffset = end;
      emitNativeTtsEvent({
        'type': 'boundary',
        'start': start,
        'end': end,
        'word': word,
      });
    });
  }

  Future<void> handleNativeTtsMessage(JavaScriptMessage message) async {
    try {
      final payload = jsonDecode(message.message);
      if (payload is! Map<String, dynamic>) return;

      final action = payload['action']?.toString();
      switch (action) {
        case 'speak':
          await speakNativeTts(payload);
          return;
        case 'pause':
          await nativeTts.pause();
          return;
        case 'resume':
          await resumeNativeTts();
          return;
        case 'cancel':
        case 'stop':
          estimatedProgressTimer?.cancel();
          await nativeTts.stop();
          return;
        default:
          return;
      }
    } catch (error) {
      emitNativeTtsEvent({'type': 'error', 'error': error.toString()});
    }
  }

  Future<void> speakNativeTts(Map<String, dynamic> payload) async {
    final text = payload['text']?.toString() ?? '';
    if (text.trim().isEmpty) return;

    activeUtteranceId = payload['id']?.toString();
    activeUtteranceText = text;
    activeUtteranceOffset = 0;
    estimatedProgressTimer?.cancel();
    await nativeTts.stop();
    await nativeTts.setLanguage(normalizeNativeTtsLanguage(payload['lang']));
    await nativeTts.setSpeechRate(normalizeNativeTtsRate(payload['rate']));
    await nativeTts.setPitch(normalizeNativeTtsPitch(payload['pitch']));
    await nativeTts.setVolume(normalizeNativeTtsVolume(payload['volume']));
    await nativeTts.speak(text);
  }

  Future<void> resumeNativeTts() async {
    if (activeUtteranceText.isEmpty) return;

    final offset = activeUtteranceOffset.clamp(0, activeUtteranceText.length);
    final text = activeUtteranceText.substring(offset);
    if (text.trim().isEmpty) return;

    estimatedProgressTimer?.cancel();
    await nativeTts.speak(text);
  }

  String normalizeNativeTtsLanguage(dynamic value) {
    final language = value?.toString().trim();
    if (language == null || language.isEmpty) return 'en-US';
    if (language.toLowerCase().startsWith('fr')) return 'fr-FR';
    return 'en-US';
  }

  double normalizeNativeTtsRate(dynamic value) {
    final rate = value is num ? value.toDouble() : double.tryParse('$value');
    final userRate = (rate ?? 1.0).clamp(0.4, 3.0).toDouble();

    // TECNO/Android TTS sounds natural around this native rate.
    // The UI still shows 1.00x as normal speed.
    if (userRate <= 1.0) return 0.4;

    return (0.4 + ((userRate - 1.0) * 0.18)).clamp(0.4, 0.9).toDouble();
  }

  double normalizeNativeTtsPitch(dynamic value) {
    final pitch = value is num ? value.toDouble() : double.tryParse('$value');
    return (pitch ?? 1.0).clamp(0.5, 2.0).toDouble();
  }

  double normalizeNativeTtsVolume(dynamic value) {
    final volume = value is num ? value.toDouble() : double.tryParse('$value');
    return (volume ?? 1.0).clamp(0.0, 1.0).toDouble();
  }

  Future<void> emitNativeTtsEvent(Map<String, dynamic> event) async {
    final id = activeUtteranceId;
    if (id == null || id.isEmpty) return;

    final payload = jsonEncode({...event, 'id': id});
    try {
      await controller.runJavaScript(
        'window.__ancientVaultTtsEvent && '
        'window.__ancientVaultTtsEvent($payload);',
      );
    } catch (_) {
      // The page may be navigating; narration events can be safely dropped.
    }
  }

  void startEstimatedProgress() {
    estimatedProgressTimer?.cancel();
    if (activeUtteranceText.isEmpty) return;

    estimatedProgressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (activeUtteranceOffset >= activeUtteranceText.length) {
        estimatedProgressTimer?.cancel();
        return;
      }

      final nextOffset = (activeUtteranceOffset + 18).clamp(
        0,
        activeUtteranceText.length,
      );
      final spokenWindow = activeUtteranceText.substring(
        activeUtteranceOffset,
        nextOffset,
      );
      final words = spokenWindow
          .trim()
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .toList(growable: false);

      emitNativeTtsEvent({
        'type': 'boundary',
        'start': activeUtteranceOffset,
        'end': nextOffset,
        'word': words.isEmpty ? '' : words.first,
      });
      activeUtteranceOffset = nextOffset;
    });
  }

  Future<void> handleBackNavigation() async {
    if (await controller.canGoBack()) {
      await controller.goBack();
      return;
    }
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) => handleBackNavigation(),
      child: Scaffold(
        body: Stack(
          children: [
            WebViewWidget(controller: controller),
            if (showLaunchSplash) const _VaultLaunchSplash(),
            if (loadProgress < 100 && !showLaunchSplash)
              LinearProgressIndicator(
                value: loadProgress == 0 ? null : loadProgress / 100,
              ),
            if (loadError != null)
              _LoadErrorBanner(
                message: loadError!,
                onRetry: () {
                  setState(() => loadError = null);
                  controller.loadRequest(Uri.parse(_vaultUrl));
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    launchSplashTimer?.cancel();
    estimatedProgressTimer?.cancel();
    nativeTts.stop();
    super.dispose();
  }
}

class _VaultLaunchSplash extends StatelessWidget {
  const _VaultLaunchSplash();

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final logoSize = (screenSize.shortestSide * 0.88)
        .clamp(300.0, 640.0)
        .toDouble();

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: SizedBox.square(
          dimension: logoSize,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(48),
            child: Image.asset(
              'assets/branding/vault_launch_logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadErrorBanner extends StatelessWidget {
  const _LoadErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A1418),
          border: Border.all(color: const Color(0xFFFF5964)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFFF5964)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Could not load vault: $message',
                style: const TextStyle(color: Color(0xFFFFA8AD)),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

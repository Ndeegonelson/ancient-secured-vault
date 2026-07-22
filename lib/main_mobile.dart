import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'services/ios_in_app_purchase_controller.dart';

const _vaultUrl = String.fromEnvironment(
  'VAULT_URL',
  defaultValue: 'https://vault.ancientsociety.tech/',
);
const _readerScreenChannel = MethodChannel(
  'ancient_secure_docs/screen_security',
);

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
  IosInAppPurchaseController? iosPurchases;
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
    launchSplashTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        showLaunchSplash = false;
      });
    });
    final isIos = Platform.isIOS;
    final webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        isIos
            ? 'AncientSecureVaultIOSApp/1.0'
            : 'AncientSecureVaultAndroidApp/1.0',
      )
      ..enableZoom(false)
      ..addJavaScriptChannel(
        'AncientVaultTts',
        onMessageReceived: handleNativeTtsMessage,
      )
      ..addJavaScriptChannel(
        'AncientVaultReader',
        onMessageReceived: handleReaderWakeLockMessage,
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
          onPageFinished: (_) async {
            launchSplashTimer?.cancel();
            if (mounted) {
              setState(() {
                loadProgress = 100;
                showLaunchSplash = false;
              });
            }
            await lockMobileWebViewZoom();
            if (isIos) {
              await iosPurchases?.initialize(silent: true);
            }
          },
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame == false) return;
            setState(() {
              loadError = error.description;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(_vaultUrl));

    if (isIos) {
      iosPurchases = IosInAppPurchaseController(onEvent: emitIosPurchaseEvent);
      webViewController.addJavaScriptChannel(
        'AncientVaultPdf',
        onMessageReceived: handleNativePdfMessage,
      );
      webViewController.addJavaScriptChannel(
        'AncientVaultIap',
        onMessageReceived: (message) {
          unawaited(iosPurchases?.handleMessage(message.message));
        },
      );
    }
    controller = webViewController;
  }

  Future<void> handleNativePdfMessage(JavaScriptMessage message) async {
    String requestId = '';
    HttpClient? client;
    try {
      final payload = jsonDecode(message.message);
      if (payload is! Map<String, dynamic> ||
          payload['action']?.toString() != 'fetch') {
        return;
      }

      requestId = payload['requestId']?.toString() ?? '';
      final url = payload['url']?.toString().trim() ?? '';
      final uri = Uri.tryParse(url);
      if (requestId.isEmpty ||
          uri == null ||
          (uri.scheme != 'https' && uri.scheme != 'http')) {
        throw const FormatException('The PDF download request is invalid.');
      }

      await emitNativePdfEvent({'type': 'started', 'requestId': requestId});

      client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/pdf,*/*');
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'PDF download returned HTTP ${response.statusCode}.',
          uri: uri,
        );
      }

      await emitNativePdfEvent({
        'type': 'response',
        'requestId': requestId,
        'contentLength': response.contentLength,
      });

      var byteCount = 0;
      var chunkIndex = 0;
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        byteCount += chunk.length;
        if (byteCount > 120 * 1024 * 1024) {
          throw const FileSystemException(
            'The PDF is too large for protected mobile rendering.',
          );
        }

        // Keep each JavaScript evaluation small. WKWebView can silently reject
        // very large source strings even though the network download succeeded.
        const bridgeChunkSize = 24 * 1024;
        for (var offset = 0; offset < chunk.length; offset += bridgeChunkSize) {
          final end = (offset + bridgeChunkSize).clamp(0, chunk.length);
          await emitNativePdfEvent({
            'type': 'chunk',
            'requestId': requestId,
            'index': chunkIndex++,
            'data': base64Encode(chunk.sublist(offset, end)),
          });
        }
      }

      if (byteCount == 0) {
        throw const FileSystemException('The downloaded PDF is empty.');
      }

      await emitNativePdfEvent({
        'type': 'complete',
        'requestId': requestId,
        'byteCount': byteCount,
        'chunkCount': chunkIndex,
      });
    } catch (error) {
      if (requestId.isNotEmpty) {
        await emitNativePdfEvent({
          'type': 'error',
          'requestId': requestId,
          'message': error.toString(),
        });
      }
    } finally {
      client?.close(force: true);
    }
  }

  Future<void> emitNativePdfEvent(Map<String, dynamic> event) async {
    final detail = jsonEncode(jsonEncode(event));
    await controller.runJavaScript(
      "window.dispatchEvent(new CustomEvent('ancientVaultPdfFetch', "
      "{detail: $detail}));",
    );
  }

  Future<void> handleReaderWakeLockMessage(JavaScriptMessage message) async {
    try {
      final payload = jsonDecode(message.message);
      if (payload is! Map<String, dynamic>) return;
      final keepAwake = payload['keepAwake'] == true;
      await _readerScreenChannel.invokeMethod<void>(
        keepAwake ? 'enableReaderStayAwake' : 'disableReaderStayAwake',
      );
    } on PlatformException {
      // The protected reader remains usable if a device rejects the flag.
    } on FormatException {
      // Ignore malformed messages from a page that is navigating away.
    }
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
    if (Platform.isIOS) {
      unawaited(configureIosNarrationAudioSession());
    }

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

  Future<void> configureIosNarrationAudioSession() async {
    await nativeTts.setSharedInstance(true);
    await nativeTts.autoStopSharedSession(false);
    await nativeTts
        .setIosAudioCategory(IosTextToSpeechAudioCategory.playback, const [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.allowAirPlay,
        ], IosTextToSpeechAudioMode.spokenAudio);
  }

  Future<void> disableReaderStayAwake() async {
    try {
      await _readerScreenChannel.invokeMethod<void>('disableReaderStayAwake');
    } on PlatformException {
      // The native shell may already be shutting down.
    } on MissingPluginException {
      // Keep disposal safe on platforms without a native screen bridge.
    }
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

  Future<void> emitIosPurchaseEvent(Map<String, dynamic> event) async {
    final payload = jsonEncode(jsonEncode(event));
    try {
      await controller.runJavaScript(
        "window.dispatchEvent(new CustomEvent('ancientVaultIap', "
        "{detail: $payload}));",
      );
    } catch (_) {
      // The web page may still be loading. It requests current StoreKit state
      // again after the dashboard becomes available.
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
      onPopInvokedWithResult: (_, _) => handleBackNavigation(),
      child: Scaffold(
        body: Stack(
          children: [
            WebViewWidget(
              controller: controller,
              gestureRecognizers: {
                Factory<OneSequenceGestureRecognizer>(
                  EagerGestureRecognizer.new,
                ),
              },
            ),
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
    unawaited(disableReaderStayAwake());
    unawaited(iosPurchases?.dispose());
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

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

const String iosPremiumYearlyProductId =
    'tech.ancientsociety.vault.premium.yearly';

const String defaultApplePurchaseVerificationUrl =
    'https://verifyapplepurchase-63jholaf6a-uc.a.run.app';

typedef IosPurchaseEventHandler = void Function(Map<String, dynamic> event);

class IosInAppPurchaseController {
  IosInAppPurchaseController({
    required this.onEvent,
    InAppPurchase? store,
    http.Client? httpClient,
    Uri? verificationUrl,
  }) : _store = store ?? InAppPurchase.instance,
       _httpClient = httpClient ?? http.Client(),
       _verificationUrl =
           verificationUrl ?? Uri.parse(defaultApplePurchaseVerificationUrl);

  final IosPurchaseEventHandler onEvent;
  final InAppPurchase _store;
  final http.Client _httpClient;
  final Uri _verificationUrl;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  ProductDetails? _premiumProduct;
  String? _firebaseIdToken;
  bool _disposed = false;

  Future<void> initialize({bool silent = false}) async {
    _purchaseSubscription ??= _store.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        _emit('error', message: 'App Store purchase update failed: $error');
      },
    );

    final available = await _store.isAvailable();
    if (!available) {
      _emit(
        'unavailable',
        message: 'The App Store is unavailable on this device.',
        extra: {if (silent) 'silent': true},
      );
      return;
    }

    final response = await _store.queryProductDetails({
      iosPremiumYearlyProductId,
    });
    if (response.error != null) {
      _emit(
        'error',
        message: response.error?.message ?? 'Could not load App Store pricing.',
        extra: {if (silent) 'silent': true},
      );
      return;
    }
    if (response.productDetails.isEmpty) {
      _emit(
        'unavailable',
        message: 'The premium subscription is not configured in the App Store.',
        extra: {if (silent) 'silent': true},
      );
      return;
    }

    _premiumProduct = response.productDetails.first;
    _emit(
      'ready',
      message: 'App Store subscription ready.',
      extra: {
        'productId': _premiumProduct!.id,
        'title': _premiumProduct!.title,
        'description': _premiumProduct!.description,
        'price': _premiumProduct!.price,
      },
    );
  }

  Future<void> handleMessage(String message) async {
    try {
      final payload = jsonDecode(message);
      if (payload is! Map<String, dynamic>) return;

      final action = payload['action']?.toString();
      final token = payload['firebaseIdToken']?.toString().trim();
      if (token != null && token.isNotEmpty) {
        _firebaseIdToken = token;
      }

      switch (action) {
        case 'status':
          await initialize(silent: true);
          return;
        case 'purchase':
          await _purchase();
          return;
        case 'restore':
          await _restore();
          return;
        default:
          _emit('error', message: 'Unsupported App Store purchase action.');
      }
    } catch (error) {
      _emit('error', message: 'Invalid App Store purchase request: $error');
    }
  }

  Future<void> _purchase() async {
    if (_firebaseIdToken == null || _firebaseIdToken!.isEmpty) {
      _emit('error', message: 'Sign in before starting an App Store purchase.');
      return;
    }
    if (_premiumProduct == null) {
      await initialize();
    }
    final product = _premiumProduct;
    if (product == null) return;

    _emit('starting', message: 'Opening the App Store purchase sheet…');
    await _store.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

  Future<void> _restore() async {
    if (_firebaseIdToken == null || _firebaseIdToken!.isEmpty) {
      _emit('error', message: 'Sign in before restoring App Store purchases.');
      return;
    }
    _emit('restoring', message: 'Restoring App Store purchases…');
    await _store.restorePurchases();
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != iosPremiumYearlyProductId) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _emit('pending', message: 'Waiting for App Store confirmation…');
          break;
        case PurchaseStatus.error:
          _emit(
            'error',
            message:
                purchase.error?.message ?? 'The App Store purchase failed.',
          );
          break;
        case PurchaseStatus.canceled:
          _emit('cancelled', message: 'The App Store purchase was cancelled.');
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndDeliver(purchase);
          break;
      }
    }
  }

  Future<void> _verifyAndDeliver(PurchaseDetails purchase) async {
    if (_isXcodeStoreKitTest(purchase)) {
      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
      _emit(
        'simulatorSuccess',
        message:
            'StoreKit test purchase succeeded. Premium access is granted only after Apple sandbox or production verification.',
      );
      return;
    }

    final token = _firebaseIdToken;
    if (token == null || token.isEmpty) {
      _emit(
        'error',
        message: 'Sign in again so this App Store purchase can be verified.',
      );
      return;
    }

    _emit('verifying', message: 'Verifying the purchase with Apple…');
    try {
      final response = await _httpClient.post(
        _verificationUrl,
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'productId': purchase.productID,
          'purchaseId': purchase.purchaseID,
          'signedTransaction': purchase.verificationData.serverVerificationData,
          'source': purchase.status == PurchaseStatus.restored
              ? 'restore'
              : 'purchase',
        }),
      );

      final decoded = response.body.trim().isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = decoded is Map<String, dynamic>
            ? decoded['error']?.toString()
            : null;
        throw StateError(message ?? 'Apple purchase verification failed.');
      }

      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
      _emit(
        'success',
        message: purchase.status == PurchaseStatus.restored
            ? 'App Store purchase restored. Premium access is active.'
            : 'App Store purchase verified. Premium access is active.',
        extra: decoded is Map<String, dynamic> ? decoded : null,
      );
    } catch (error) {
      _emit(
        'error',
        message:
            'The purchase is safe but premium access could not be verified yet: $error',
      );
    }
  }

  bool _isXcodeStoreKitTest(PurchaseDetails purchase) {
    try {
      final decoded = jsonDecode(
        purchase.verificationData.localVerificationData,
      );
      if (decoded is! Map<String, dynamic>) return false;
      return decoded['environment']?.toString().toLowerCase() == 'xcode';
    } catch (_) {
      return false;
    }
  }

  void _emit(
    String type, {
    required String message,
    Map<String, dynamic>? extra,
  }) {
    if (_disposed) return;
    onEvent({'type': type, 'message': message, ...?extra});
  }

  Future<void> dispose() async {
    _disposed = true;
    await _purchaseSubscription?.cancel();
    _httpClient.close();
  }
}

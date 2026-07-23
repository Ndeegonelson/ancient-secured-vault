import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

const String googlePlayPremiumYearlyProductId =
    'tech.ancientsociety.vault.premium.yearly';

const String defaultGooglePlayPurchaseVerificationUrl =
    'https://us-central1-ancient--docs.cloudfunctions.net/verifyGooglePlayPurchase';

typedef GooglePlayPurchaseEventHandler =
    void Function(Map<String, dynamic> event);

class GooglePlayInAppPurchaseController {
  GooglePlayInAppPurchaseController({
    required this.onEvent,
    InAppPurchase? store,
    http.Client? httpClient,
    Uri? verificationUrl,
  }) : _store = store ?? InAppPurchase.instance,
       _httpClient = httpClient ?? http.Client(),
       _verificationUrl =
           verificationUrl ??
           Uri.parse(defaultGooglePlayPurchaseVerificationUrl);

  final GooglePlayPurchaseEventHandler onEvent;
  final InAppPurchase _store;
  final http.Client _httpClient;
  final Uri _verificationUrl;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  ProductDetails? _premiumProduct;
  String? _firebaseIdToken;
  String? _firebaseUid;
  bool _disposed = false;

  Future<void> initialize({bool silent = false}) async {
    _purchaseSubscription ??= _store.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        _emit('error', message: 'Google Play purchase update failed: $error');
      },
    );

    final available = await _store.isAvailable();
    if (!available) {
      _emit(
        'unavailable',
        message: 'Google Play Billing is unavailable on this device.',
        extra: {if (silent) 'silent': true},
      );
      return;
    }

    final response = await _store.queryProductDetails({
      googlePlayPremiumYearlyProductId,
    });
    if (response.error != null) {
      _emit(
        'error',
        message:
            response.error?.message ??
            'Could not load Google Play subscription pricing.',
        extra: {if (silent) 'silent': true},
      );
      return;
    }
    if (response.productDetails.isEmpty) {
      _emit(
        'unavailable',
        message:
            'The premium subscription is not configured in Google Play yet.',
        extra: {if (silent) 'silent': true},
      );
      return;
    }

    _premiumProduct = response.productDetails.first;
    _emit(
      'ready',
      message: 'Google Play subscription ready.',
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
      final uid = payload['firebaseUid']?.toString().trim();
      if (token != null && token.isNotEmpty) _firebaseIdToken = token;
      if (uid != null && uid.isNotEmpty) _firebaseUid = uid;

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
          _emit('error', message: 'Unsupported Google Play purchase action.');
      }
    } catch (error) {
      _emit('error', message: 'Invalid Google Play purchase request: $error');
    }
  }

  Future<void> _purchase() async {
    if (!_hasAuthenticatedUser) {
      _emit(
        'error',
        message: 'Sign in before starting a Google Play purchase.',
      );
      return;
    }
    if (_premiumProduct == null) await initialize();
    final product = _premiumProduct;
    if (product == null) return;

    _emit('starting', message: 'Opening Google Play checkout…');
    final launched = await _store.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: product,
        applicationUserName: _obfuscatedAccountId(_firebaseUid!),
      ),
    );
    if (!launched) {
      _emit('error', message: 'Google Play checkout could not start.');
    }
  }

  Future<void> _restore() async {
    if (!_hasAuthenticatedUser) {
      _emit(
        'error',
        message: 'Sign in before restoring Google Play purchases.',
      );
      return;
    }
    _emit('restoring', message: 'Checking Google Play purchases…');
    await _store.restorePurchases();
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != googlePlayPremiumYearlyProductId) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _emit(
            'pending',
            message: 'Google Play is still processing this payment.',
          );
          break;
        case PurchaseStatus.error:
          _emit(
            'error',
            message:
                purchase.error?.message ?? 'The Google Play purchase failed.',
          );
          break;
        case PurchaseStatus.canceled:
          _emit(
            'cancelled',
            message: 'The Google Play purchase was cancelled.',
          );
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndDeliver(purchase);
          break;
      }
    }
  }

  Future<void> _verifyAndDeliver(PurchaseDetails purchase) async {
    final token = _firebaseIdToken;
    if (token == null || token.isEmpty) {
      _emit(
        'error',
        message: 'Sign in again so this Google Play purchase can be verified.',
      );
      return;
    }

    final purchaseToken = purchase.verificationData.serverVerificationData
        .trim();
    if (purchaseToken.isEmpty) {
      _emit('error', message: 'Google Play did not return a purchase token.');
      return;
    }

    _emit('verifying', message: 'Verifying the purchase with Google Play…');
    try {
      final response = await _httpClient.post(
        _verificationUrl,
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'productId': purchase.productID,
          'purchaseToken': purchaseToken,
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
        throw StateError(message ?? 'Google Play verification failed.');
      }

      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
      _emit(
        'success',
        message: purchase.status == PurchaseStatus.restored
            ? 'Google Play subscription restored. Premium access is active.'
            : 'Google Play subscription verified. Premium access is active.',
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

  bool get _hasAuthenticatedUser =>
      _firebaseIdToken?.isNotEmpty == true && _firebaseUid?.isNotEmpty == true;

  String _obfuscatedAccountId(String uid) {
    return sha256.convert(utf8.encode(uid.trim())).toString();
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

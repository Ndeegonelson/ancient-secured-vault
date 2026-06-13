import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

typedef UserSubscriptionAuthTokenProvider = Future<String?> Function();

class UserSubscriptionCheckoutException implements Exception {
  const UserSubscriptionCheckoutException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() {
    if (code == null || code!.isEmpty) return message;
    return '$message ($code)';
  }
}

class UserSubscriptionCheckoutResult {
  const UserSubscriptionCheckoutResult({
    required this.requestId,
    required this.checkoutUrl,
  });

  final String requestId;
  final Uri checkoutUrl;
}

class UserSubscriptionBillingPortalResult {
  const UserSubscriptionBillingPortalResult({required this.portalUrl});

  final Uri portalUrl;
}

class UserSubscriptionCheckoutClient {
  const UserSubscriptionCheckoutClient({
    required this.projectId,
    required this.authTokenProvider,
    this.region = 'us-central1',
    this.httpClient,
    this.originOverride,
    this.checkoutFunctionUrl,
    this.billingPortalFunctionUrl,
    this.paystackCheckoutFunctionUrl,
  });

  factory UserSubscriptionCheckoutClient.firebase({
    required FirebaseOptions options,
    FirebaseAuth? auth,
    String region = 'us-central1',
    http.Client? httpClient,
    Uri? originOverride,
    Uri? checkoutFunctionUrl,
    Uri? billingPortalFunctionUrl,
    Uri? paystackCheckoutFunctionUrl,
  }) {
    final firebaseAuth = auth ?? FirebaseAuth.instance;
    return UserSubscriptionCheckoutClient(
      projectId: options.projectId,
      region: region,
      httpClient: httpClient,
      originOverride: originOverride,
      checkoutFunctionUrl: checkoutFunctionUrl,
      billingPortalFunctionUrl: billingPortalFunctionUrl,
      paystackCheckoutFunctionUrl: paystackCheckoutFunctionUrl,
      authTokenProvider: () async => firebaseAuth.currentUser?.getIdToken(),
    );
  }

  final String projectId;
  final String region;
  final http.Client? httpClient;
  final Uri? originOverride;
  final Uri? checkoutFunctionUrl;
  final Uri? billingPortalFunctionUrl;
  final Uri? paystackCheckoutFunctionUrl;
  final UserSubscriptionAuthTokenProvider authTokenProvider;

  Future<UserSubscriptionCheckoutResult> createStripeCheckoutSession({
    String message = '',
    Uri? successUrl,
    Uri? cancelUrl,
  }) async {
    final authToken = await authTokenProvider();
    if (authToken == null || authToken.trim().isEmpty) {
      throw const UserSubscriptionCheckoutException(
        'Sign in before starting Stripe checkout.',
        code: 'unauthenticated',
      );
    }

    final client = httpClient ?? http.Client();
    final shouldCloseClient = httpClient == null;
    try {
      final response = await client
          .post(
            checkoutFunctionUrl ?? _functionUri('createStripeCheckoutSession'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer ${authToken.trim()}',
            },
            body: jsonEncode({
              'data': {
                if (message.trim().isNotEmpty) 'message': message.trim(),
                if (successUrl != null) 'successUrl': successUrl.toString(),
                if (cancelUrl != null) 'cancelUrl': cancelUrl.toString(),
              },
            }),
          )
          .timeout(const Duration(seconds: 45));

      return _decodeCheckoutResponse(response, providerName: 'Stripe');
    } finally {
      if (shouldCloseClient) client.close();
    }
  }

  Future<UserSubscriptionBillingPortalResult> createStripeBillingPortalSession({
    Uri? returnUrl,
  }) async {
    final authToken = await authTokenProvider();
    if (authToken == null || authToken.trim().isEmpty) {
      throw const UserSubscriptionCheckoutException(
        'Sign in before managing Stripe billing.',
        code: 'unauthenticated',
      );
    }

    final client = httpClient ?? http.Client();
    final shouldCloseClient = httpClient == null;
    try {
      final response = await client
          .post(
            billingPortalFunctionUrl ??
                _functionUri('createStripeBillingPortalSession'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer ${authToken.trim()}',
            },
            body: jsonEncode({
              'data': {
                if (returnUrl != null) 'returnUrl': returnUrl.toString(),
              },
            }),
          )
          .timeout(const Duration(seconds: 45));

      return _decodePortalResponse(response);
    } finally {
      if (shouldCloseClient) client.close();
    }
  }

  Future<UserSubscriptionCheckoutResult> createPaystackCheckoutSession({
    String message = '',
    Uri? successUrl,
  }) async {
    final authToken = await authTokenProvider();
    if (authToken == null || authToken.trim().isEmpty) {
      throw const UserSubscriptionCheckoutException(
        'Sign in before starting Paystack checkout.',
        code: 'unauthenticated',
      );
    }

    final client = httpClient ?? http.Client();
    final shouldCloseClient = httpClient == null;
    try {
      final response = await client
          .post(
            paystackCheckoutFunctionUrl ??
                _functionUri('createPaystackCheckoutSession'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer ${authToken.trim()}',
            },
            body: jsonEncode({
              'data': {
                if (message.trim().isNotEmpty) 'message': message.trim(),
                if (successUrl != null) 'successUrl': successUrl.toString(),
              },
            }),
          )
          .timeout(const Duration(seconds: 45));

      return _decodeCheckoutResponse(response, providerName: 'Paystack');
    } finally {
      if (shouldCloseClient) client.close();
    }
  }

  Uri _functionUri(String functionName) {
    final origin =
        originOverride ??
        Uri.parse('https://$region-$projectId.cloudfunctions.net');
    return origin.replace(pathSegments: [...origin.pathSegments, functionName]);
  }

  UserSubscriptionCheckoutResult _decodeCheckoutResponse(
    http.Response response, {
    required String providerName,
  }) {
    final decodedBody = _decodeBody(response.body);
    final error = decodedBody['error'];
    if (error is Map) {
      throw UserSubscriptionCheckoutException(
        _errorMessage(error),
        code: error['status']?.toString(),
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw UserSubscriptionCheckoutException(
        '$providerName checkout could not start.',
        code: response.statusCode.toString(),
      );
    }

    final checkoutUrl = Uri.tryParse(
      decodedBody['checkoutUrl']?.toString() ?? '',
    );
    final requestId = decodedBody['requestId']?.toString().trim() ?? '';
    if (checkoutUrl == null || requestId.isEmpty) {
      throw UserSubscriptionCheckoutException(
        '$providerName checkout response is invalid.',
      );
    }

    return UserSubscriptionCheckoutResult(
      requestId: requestId,
      checkoutUrl: checkoutUrl,
    );
  }

  UserSubscriptionBillingPortalResult _decodePortalResponse(
    http.Response response,
  ) {
    final decodedBody = _decodeBody(response.body);
    final error = decodedBody['error'];
    if (error is Map) {
      throw UserSubscriptionCheckoutException(
        _errorMessage(error),
        code: error['status']?.toString(),
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw UserSubscriptionCheckoutException(
        'Stripe billing portal could not start.',
        code: response.statusCode.toString(),
      );
    }

    final portalUrl = Uri.tryParse(decodedBody['portalUrl']?.toString() ?? '');
    if (portalUrl == null) {
      throw const UserSubscriptionCheckoutException(
        'Stripe billing portal response is invalid.',
      );
    }

    return UserSubscriptionBillingPortalResult(portalUrl: portalUrl);
  }

  Map<String, dynamic> _decodeBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      throw const UserSubscriptionCheckoutException(
        'Subscription checkout response is not valid JSON.',
      );
    }

    throw const UserSubscriptionCheckoutException(
      'Subscription checkout response is invalid.',
    );
  }

  String _errorMessage(Map<dynamic, dynamic> error) {
    final message = error['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }

    return 'Subscription checkout is temporarily unavailable.';
  }
}

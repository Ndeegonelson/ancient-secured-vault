import 'dart:convert';

import 'package:ancient_secure_docs/services/user_subscription_checkout_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('starts Stripe checkout with auth and return URLs', () async {
    late http.Request capturedRequest;
    final client = UserSubscriptionCheckoutClient(
      projectId: 'ancient--docs',
      authTokenProvider: () async => 'user-token',
      originOverride: Uri.parse('https://functions.test'),
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'requestId': 'request-1',
            'checkoutUrl': 'https://checkout.stripe.com/c/pay/test',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await client.createStripeCheckoutSession(
      message: ' Premium please. ',
      successUrl: Uri.parse('https://app.test/success'),
      cancelUrl: Uri.parse('https://app.test/cancel'),
    );

    expect(result.requestId, 'request-1');
    expect(
      result.checkoutUrl,
      Uri.parse('https://checkout.stripe.com/c/pay/test'),
    );
    expect(
      capturedRequest.url,
      Uri.parse('https://functions.test/createStripeCheckoutSession'),
    );
    expect(capturedRequest.headers['Authorization'], 'Bearer user-token');
    expect(capturedRequest.headers['Content-Type'], 'application/json');
    expect(jsonDecode(capturedRequest.body), {
      'data': {
        'message': 'Premium please.',
        'successUrl': 'https://app.test/success',
        'cancelUrl': 'https://app.test/cancel',
      },
    });
  });

  test('requires a signed-in user before Stripe checkout', () async {
    final client = UserSubscriptionCheckoutClient(
      projectId: 'ancient--docs',
      authTokenProvider: () async => null,
      httpClient: MockClient((request) async {
        fail('No request should be sent without auth.');
      }),
    );

    await expectLater(
      client.createStripeCheckoutSession(),
      throwsA(isA<UserSubscriptionCheckoutException>()),
    );
  });

  test('starts Stripe billing portal with auth and return URL', () async {
    late http.Request capturedRequest;
    final client = UserSubscriptionCheckoutClient(
      projectId: 'ancient--docs',
      authTokenProvider: () async => 'user-token',
      originOverride: Uri.parse('https://functions.test'),
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'portalUrl': 'https://billing.stripe.com/p/session/test',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await client.createStripeBillingPortalSession(
      returnUrl: Uri.parse('https://app.test/dashboard'),
    );

    expect(
      result.portalUrl,
      Uri.parse('https://billing.stripe.com/p/session/test'),
    );
    expect(
      capturedRequest.url,
      Uri.parse('https://functions.test/createStripeBillingPortalSession'),
    );
    expect(capturedRequest.headers['Authorization'], 'Bearer user-token');
    expect(capturedRequest.headers['Content-Type'], 'application/json');
    expect(jsonDecode(capturedRequest.body), {
      'data': {'returnUrl': 'https://app.test/dashboard'},
    });
  });

  test('starts Paystack checkout with auth and return URL', () async {
    late http.Request capturedRequest;
    final client = UserSubscriptionCheckoutClient(
      projectId: 'ancient--docs',
      authTokenProvider: () async => 'user-token',
      originOverride: Uri.parse('https://functions.test'),
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'requestId': 'request-2',
            'checkoutUrl': 'https://checkout.paystack.com/test',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await client.createPaystackCheckoutSession(
      message: ' Paystack premium. ',
      successUrl: Uri.parse('https://app.test/paystack-success'),
    );

    expect(result.requestId, 'request-2');
    expect(result.checkoutUrl, Uri.parse('https://checkout.paystack.com/test'));
    expect(
      capturedRequest.url,
      Uri.parse('https://functions.test/createPaystackCheckoutSession'),
    );
    expect(capturedRequest.headers['Authorization'], 'Bearer user-token');
    expect(capturedRequest.headers['Content-Type'], 'application/json');
    expect(jsonDecode(capturedRequest.body), {
      'data': {
        'message': 'Paystack premium.',
        'successUrl': 'https://app.test/paystack-success',
      },
    });
  });
}

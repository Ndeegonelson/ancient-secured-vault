import 'dart:convert';

import 'package:ancient_secure_docs/services/reader_cloud_narration_http_callable_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('readiness is ready when auth and app check tokens exist', () async {
    final client = ReaderCloudNarrationHttpCallableClient(
      projectId: 'ancient--docs',
      authTokenProvider: () async => 'user-token',
      appCheckTokenProvider: () async => 'app-check-token',
    );

    final readiness = await client.checkReadiness();

    expect(readiness.isReady, isTrue);
    expect(readiness.message, 'Secure cloud narration is ready.');
  });

  test('readiness asks user to sign in when auth token is missing', () async {
    final client = ReaderCloudNarrationHttpCallableClient(
      projectId: 'ancient--docs',
      authTokenProvider: () async => null,
      appCheckTokenProvider: () async => 'app-check-token',
    );

    final readiness = await client.checkReadiness();

    expect(readiness.isReady, isFalse);
    expect(readiness.message, 'Sign in before using cloud narration.');
  });

  test(
    'readiness reports missing app check setup before catalog loading',
    () async {
      final client = ReaderCloudNarrationHttpCallableClient(
        projectId: 'ancient--docs',
        authTokenProvider: () async => 'user-token',
        appCheckTokenProvider: () async => null,
      );

      final readiness = await client.checkReadiness();

      expect(readiness.isReady, isFalse);
      expect(
        readiness.message,
        'Secure cloud narration is waiting for App Check setup.',
      );
    },
  );

  test('posts callable request with auth and app check headers', () async {
    late http.Request capturedRequest;
    final client = ReaderCloudNarrationHttpCallableClient(
      projectId: 'ancient--docs',
      region: 'us-central1',
      originOverride: Uri.parse('https://functions.test'),
      authTokenProvider: () async => 'user-token',
      appCheckTokenProvider: () async => 'app-check-token',
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'result': {'status': 'ready', 'voices': []},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await client.call('cloudNarrationCatalog', const {});

    expect(result, {'status': 'ready', 'voices': []});
    expect(
      capturedRequest.url,
      Uri.parse('https://functions.test/cloudNarrationCatalog'),
    );
    expect(capturedRequest.headers['Authorization'], 'Bearer user-token');
    expect(capturedRequest.headers['X-Firebase-AppCheck'], 'app-check-token');
    expect(capturedRequest.headers['Content-Type'], 'application/json');
    expect(jsonDecode(capturedRequest.body), {'data': <String, dynamic>{}});
  });

  test(
    'builds default Firebase callable URL from project and region',
    () async {
      late Uri capturedUri;
      final client = ReaderCloudNarrationHttpCallableClient(
        projectId: 'ancient--docs',
        region: 'europe-west1',
        authTokenProvider: () async => null,
        requiresAppCheckToken: false,
        httpClient: MockClient((request) async {
          capturedUri = request.url;
          return http.Response(
            jsonEncode({
              'result': {'ok': true},
            }),
            200,
          );
        }),
      );

      await client.call('synthesizeCloudNarration', {'text': 'Hello'});

      expect(
        capturedUri,
        Uri.parse(
          'https://europe-west1-ancient--docs.cloudfunctions.net/'
          'synthesizeCloudNarration',
        ),
      );
    },
  );

  test(
    'stops before network when required app check token is missing',
    () async {
      var networkCalls = 0;
      final client = ReaderCloudNarrationHttpCallableClient(
        projectId: 'ancient--docs',
        authTokenProvider: () async => 'user-token',
        appCheckTokenProvider: () async => null,
        httpClient: MockClient((request) async {
          networkCalls++;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        client.call('cloudNarrationCatalog', const {}),
        throwsA(
          isA<ReaderCloudNarrationCallableException>()
              .having(
                (error) => error.message,
                'message',
                'Secure cloud narration is waiting for App Check setup.',
              )
              .having((error) => error.code, 'code', 'failed-precondition'),
        ),
      );
      expect(networkCalls, 0);
    },
  );

  test('throws readable error for Firebase callable errors', () async {
    final client = ReaderCloudNarrationHttpCallableClient(
      projectId: 'ancient--docs',
      authTokenProvider: () async => null,
      requiresAppCheckToken: false,
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'status': 'permission-denied',
              'message': 'Premium narration is required.',
            },
          }),
          403,
        );
      }),
    );

    await expectLater(
      client.call('cloudNarrationCatalog', const {}),
      throwsA(
        isA<ReaderCloudNarrationCallableException>()
            .having(
              (error) => error.message,
              'message',
              'Premium narration is required.',
            )
            .having((error) => error.code, 'code', 'permission-denied'),
      ),
    );
  });

  test('throws readable error for invalid JSON responses', () async {
    final client = ReaderCloudNarrationHttpCallableClient(
      projectId: 'ancient--docs',
      authTokenProvider: () async => null,
      requiresAppCheckToken: false,
      httpClient: MockClient((request) async {
        return http.Response('not-json', 200);
      }),
    );

    await expectLater(
      client.call('cloudNarrationCatalog', const {}),
      throwsA(
        isA<ReaderCloudNarrationCallableException>().having(
          (error) => error.message,
          'message',
          'Cloud narration response is not valid JSON.',
        ),
      ),
    );
  });
}

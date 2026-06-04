import 'dart:convert';

import 'package:ancient_secure_docs/services/reader_cloud_narration_http_callable_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
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

  test('throws readable error for Firebase callable errors', () async {
    final client = ReaderCloudNarrationHttpCallableClient(
      projectId: 'ancient--docs',
      authTokenProvider: () async => null,
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

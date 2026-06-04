import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

import 'reader_cloud_narration_callable_provider.dart';

typedef ReaderCloudNarrationTokenProvider = Future<String?> Function();

class ReaderCloudNarrationCallableException implements Exception {
  const ReaderCloudNarrationCallableException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() {
    if (code == null || code!.isEmpty) return message;
    return '$message ($code)';
  }
}

class ReaderCloudNarrationHttpCallableClient
    implements ReaderCloudNarrationCallableClient {
  const ReaderCloudNarrationHttpCallableClient({
    required this.projectId,
    required this.authTokenProvider,
    this.appCheckTokenProvider,
    this.requiresAppCheckToken = true,
    this.region = 'us-central1',
    this.httpClient,
    this.originOverride,
  });

  factory ReaderCloudNarrationHttpCallableClient.firebase({
    required FirebaseOptions options,
    FirebaseAuth? auth,
    ReaderCloudNarrationTokenProvider? appCheckTokenProvider,
    bool requiresAppCheckToken = true,
    String region = 'us-central1',
    http.Client? httpClient,
    Uri? originOverride,
  }) {
    final firebaseAuth = auth ?? FirebaseAuth.instance;
    return ReaderCloudNarrationHttpCallableClient(
      projectId: options.projectId,
      region: region,
      httpClient: httpClient,
      originOverride: originOverride,
      authTokenProvider: () async => firebaseAuth.currentUser?.getIdToken(),
      appCheckTokenProvider: appCheckTokenProvider,
      requiresAppCheckToken: requiresAppCheckToken,
    );
  }

  final String projectId;
  final String region;
  final http.Client? httpClient;
  final Uri? originOverride;
  final ReaderCloudNarrationTokenProvider authTokenProvider;
  final ReaderCloudNarrationTokenProvider? appCheckTokenProvider;
  final bool requiresAppCheckToken;

  @override
  Future<Map<String, dynamic>> call(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    final client = httpClient ?? http.Client();
    final shouldCloseClient = httpClient == null;
    try {
      final response = await client.post(
        _callableUri(functionName),
        headers: await _headers(),
        body: jsonEncode({'data': data}),
      );

      return _decodeResponse(response);
    } finally {
      if (shouldCloseClient) client.close();
    }
  }

  Uri _callableUri(String functionName) {
    final safeFunctionName = functionName.trim();
    if (safeFunctionName.isEmpty) {
      throw const ReaderCloudNarrationCallableException(
        'Cloud narration function name is missing.',
      );
    }

    final origin =
        originOverride ??
        Uri.parse('https://$region-$projectId.cloudfunctions.net');
    return origin.replace(
      pathSegments: [...origin.pathSegments, safeFunctionName],
    );
  }

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final authToken = await authTokenProvider();
    if (authToken != null && authToken.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${authToken.trim()}';
    }

    final appCheckToken = await appCheckTokenProvider?.call();
    if (appCheckToken != null && appCheckToken.trim().isNotEmpty) {
      headers['X-Firebase-AppCheck'] = appCheckToken.trim();
    } else if (requiresAppCheckToken) {
      throw const ReaderCloudNarrationCallableException(
        'Secure cloud narration is waiting for App Check setup.',
        code: 'failed-precondition',
      );
    }

    return headers;
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final decodedBody = _decodeBody(response.body);
    final callableError = decodedBody['error'];

    if (callableError is Map) {
      throw ReaderCloudNarrationCallableException(
        _errorMessage(callableError),
        code: callableError['status']?.toString(),
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ReaderCloudNarrationCallableException(
        'Cloud narration request failed.',
        code: response.statusCode.toString(),
      );
    }

    final result = decodedBody['result'];
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);

    throw const ReaderCloudNarrationCallableException(
      'Cloud narration response is invalid.',
    );
  }

  Map<String, dynamic> _decodeBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      throw const ReaderCloudNarrationCallableException(
        'Cloud narration response is not valid JSON.',
      );
    }

    throw const ReaderCloudNarrationCallableException(
      'Cloud narration response is invalid.',
    );
  }

  String _errorMessage(Map<dynamic, dynamic> error) {
    final message = error['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }

    return 'Cloud narration is temporarily unavailable.';
  }
}

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

typedef SecureVaultSearchAuthTokenProvider = Future<String?> Function();

class SecureVaultSearchException implements Exception {
  const SecureVaultSearchException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() {
    if (code == null || code!.isEmpty) return message;
    return '$message ($code)';
  }
}

class SecureVaultSearchResult {
  const SecureVaultSearchResult({
    required this.id,
    required this.pdfTitle,
    required this.pageNumber,
    required this.category,
    required this.accessLevel,
    required this.text,
    required this.storagePath,
    this.readerMode = '',
    this.protectionMode = '',
    this.pdfUrl,
  });

  final String id;
  final String pdfTitle;
  final int pageNumber;
  final String category;
  final String accessLevel;
  final String text;
  final String storagePath;
  final String readerMode;
  final String protectionMode;
  final String? pdfUrl;

  Map<String, dynamic> toLegacySearchData() {
    return {
      'id': id,
      'pdfTitle': pdfTitle,
      'pageNumber': pageNumber,
      'category': category,
      'accessLevel': accessLevel,
      'text': text,
      'storagePath': storagePath,
      'readerMode': readerMode,
      'protectionMode': protectionMode,
      if (pdfUrl != null && pdfUrl!.trim().isNotEmpty) 'pdfUrl': pdfUrl,
    };
  }
}

class SecureVaultSearchResponse {
  const SecureVaultSearchResponse({
    required this.query,
    required this.searchTerms,
    required this.results,
  });

  final String query;
  final List<String> searchTerms;
  final List<SecureVaultSearchResult> results;
}

class SecureVaultSearchClient {
  const SecureVaultSearchClient({
    required this.projectId,
    required this.authTokenProvider,
    this.region = 'us-central1',
    this.httpClient,
    this.originOverride,
    this.searchFunctionUrl,
  });

  factory SecureVaultSearchClient.firebase({
    required FirebaseOptions options,
    FirebaseAuth? auth,
    String region = 'us-central1',
    http.Client? httpClient,
    Uri? originOverride,
    Uri? searchFunctionUrl,
  }) {
    final firebaseAuth = auth ?? FirebaseAuth.instance;

    return SecureVaultSearchClient(
      projectId: options.projectId,
      region: region,
      httpClient: httpClient,
      originOverride: originOverride,
      searchFunctionUrl: searchFunctionUrl,
      authTokenProvider: () async => firebaseAuth.currentUser?.getIdToken(),
    );
  }

  final String projectId;
  final String region;
  final http.Client? httpClient;
  final Uri? originOverride;
  final Uri? searchFunctionUrl;
  final SecureVaultSearchAuthTokenProvider authTokenProvider;

  Future<SecureVaultSearchResponse> search(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      throw const SecureVaultSearchException('Enter a searchable word.');
    }

    final authToken = await authTokenProvider();
    if (authToken == null || authToken.trim().isEmpty) {
      throw const SecureVaultSearchException(
        'Sign in before searching the vault.',
        code: 'unauthenticated',
      );
    }

    final client = httpClient ?? http.Client();
    final shouldCloseClient = httpClient == null;

    try {
      final response = await client
          .post(
            searchFunctionUrl ?? _functionUri('searchVaultDocuments'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer ${authToken.trim()}',
            },
            body: jsonEncode({
              'data': {'query': trimmedQuery},
            }),
          )
          .timeout(const Duration(seconds: 45));

      return _decodeSearchResponse(response);
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

  SecureVaultSearchResponse _decodeSearchResponse(http.Response response) {
    final decodedBody = _decodeBody(response.body);
    final error = decodedBody['error'];

    if (error is Map) {
      throw SecureVaultSearchException(
        _errorMessage(error),
        code: error['status']?.toString(),
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SecureVaultSearchException(
        'Vault search could not load results right now.',
        code: response.statusCode.toString(),
      );
    }

    final rawResults = decodedBody['results'];
    if (rawResults is! List) {
      throw const SecureVaultSearchException(
        'Vault search response is invalid.',
      );
    }

    final rawTerms = decodedBody['searchTerms'];

    return SecureVaultSearchResponse(
      query: decodedBody['query']?.toString() ?? '',
      searchTerms: rawTerms is List
          ? rawTerms.map((term) => term.toString()).toList(growable: false)
          : const [],
      results: rawResults
          .whereType<Map>()
          .map(_resultFromMap)
          .toList(growable: false),
    );
  }

  SecureVaultSearchResult _resultFromMap(Map<dynamic, dynamic> item) {
    final pdfUrl = item['pdfUrl']?.toString().trim();

    return SecureVaultSearchResult(
      id: item['id']?.toString() ?? '',
      pdfTitle: item['pdfTitle']?.toString() ?? '',
      pageNumber: _safeInt(item['pageNumber']),
      category: item['category']?.toString() ?? 'General',
      accessLevel: item['accessLevel']?.toString() ?? 'free',
      text: item['text']?.toString() ?? '',
      storagePath: item['storagePath']?.toString() ?? '',
      readerMode: item['readerMode']?.toString() ?? '',
      protectionMode: item['protectionMode']?.toString() ?? '',
      pdfUrl: pdfUrl == null || pdfUrl.isEmpty ? null : pdfUrl,
    );
  }

  Map<String, dynamic> _decodeBody(String body) {
    try {
      final decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      throw const SecureVaultSearchException(
        'Vault search response is not valid JSON.',
      );
    }

    throw const SecureVaultSearchException(
      'Vault search response is invalid.',
    );
  }

  String _errorMessage(Map<dynamic, dynamic> error) {
    final message = error['message'];

    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }

    return 'Vault search is temporarily unavailable.';
  }

  int _safeInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

class ReaderNarrationPreferences {
  const ReaderNarrationPreferences({
    required this.languageMode,
    required this.rate,
    this.voiceId,
  });

  factory ReaderNarrationPreferences.fromMap(Map<String, dynamic> data) {
    return ReaderNarrationPreferences(
      languageMode: data['languageMode']?.toString() ?? 'en-US',
      rate: _readDouble(data['rate'], fallback: 0.5),
      voiceId: _readOptionalString(data['voiceId']),
    );
  }

  final String languageMode;
  final double rate;
  final String? voiceId;

  static double _readDouble(dynamic value, {required double fallback}) {
    return double.tryParse(value.toString()) ?? fallback;
  }

  static String? _readOptionalString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

abstract interface class ReaderNarrationPreferencesStore {
  Future<ReaderNarrationPreferences?> load({required String userEmail});

  Future<void> save({
    required String userEmail,
    required ReaderNarrationPreferences preferences,
  });
}

class ReaderNarrationPreferencesRepository
    implements ReaderNarrationPreferencesStore {
  ReaderNarrationPreferencesRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<ReaderNarrationPreferences?> load({required String userEmail}) async {
    final snapshot = await _document(userEmail).get();
    final data = snapshot.data();

    return data == null ? null : ReaderNarrationPreferences.fromMap(data);
  }

  @override
  Future<void> save({
    required String userEmail,
    required ReaderNarrationPreferences preferences,
  }) async {
    await _document(userEmail).set({
      'userEmail': userEmail,
      'languageMode': preferences.languageMode,
      'rate': preferences.rate,
      'voiceId': preferences.voiceId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  DocumentReference<Map<String, dynamic>> _document(String userEmail) {
    final normalizedEmail = userEmail.trim().toLowerCase();
    final documentId = base64Url.encode(utf8.encode(normalizedEmail));

    return _firestore
        .collection('reader_narration_preferences')
        .doc(documentId);
  }
}

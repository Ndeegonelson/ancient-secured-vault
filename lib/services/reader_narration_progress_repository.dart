import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

class ReaderNarrationCheckpoint {
  const ReaderNarrationCheckpoint({
    required this.pageNumber,
    required this.characterOffset,
    required this.textLength,
    required this.languageLocale,
    required this.rate,
  });

  factory ReaderNarrationCheckpoint.fromMap(Map<String, dynamic> data) {
    return ReaderNarrationCheckpoint(
      pageNumber: _readInt(data['pageNumber'], fallback: 1),
      characterOffset: _readInt(data['characterOffset']),
      textLength: _readInt(data['textLength']),
      languageLocale: data['languageLocale']?.toString() ?? 'en-US',
      rate: _readDouble(data['rate'], fallback: 0.5),
    );
  }

  final int pageNumber;
  final int characterOffset;
  final int textLength;
  final String languageLocale;
  final double rate;

  bool get isResumable => characterOffset > 0 && characterOffset < textLength;

  int get progressPercent {
    if (textLength <= 0) return 0;

    return ((characterOffset / textLength).clamp(0, 1) * 100).round();
  }

  int characterOffsetForText(String text) {
    if (text.isEmpty || characterOffset >= text.length) return 0;

    return characterOffset.clamp(0, text.length - 1);
  }

  static int _readInt(dynamic value, {int fallback = 0}) {
    return int.tryParse(value.toString()) ?? fallback;
  }

  static double _readDouble(dynamic value, {double fallback = 0}) {
    return double.tryParse(value.toString()) ?? fallback;
  }
}

abstract interface class ReaderNarrationProgressStore {
  Future<ReaderNarrationCheckpoint?> load({
    required String userEmail,
    required String documentKey,
    required int pageNumber,
  });

  Future<void> save({
    required String userEmail,
    required String documentKey,
    required String pdfTitle,
    required String storagePath,
    required ReaderNarrationCheckpoint checkpoint,
  });

  Future<void> clear({
    required String userEmail,
    required String documentKey,
    required int pageNumber,
  });
}

class ReaderNarrationProgressRepository
    implements ReaderNarrationProgressStore {
  ReaderNarrationProgressRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<ReaderNarrationCheckpoint?> load({
    required String userEmail,
    required String documentKey,
    required int pageNumber,
  }) async {
    final snapshot = await _document(
      userEmail: userEmail,
      documentKey: documentKey,
      pageNumber: pageNumber,
    ).get();
    final data = snapshot.data();

    if (data == null) return null;

    final checkpoint = ReaderNarrationCheckpoint.fromMap(data);
    return checkpoint.isResumable ? checkpoint : null;
  }

  @override
  Future<void> save({
    required String userEmail,
    required String documentKey,
    required String pdfTitle,
    required String storagePath,
    required ReaderNarrationCheckpoint checkpoint,
  }) async {
    if (!checkpoint.isResumable) return;

    await _document(
      userEmail: userEmail,
      documentKey: documentKey,
      pageNumber: checkpoint.pageNumber,
    ).set({
      'userEmail': userEmail,
      'documentKey': documentKey,
      'pdfTitle': pdfTitle,
      'storagePath': storagePath,
      'pageNumber': checkpoint.pageNumber,
      'characterOffset': checkpoint.characterOffset,
      'textLength': checkpoint.textLength,
      'progressPercent': checkpoint.progressPercent,
      'languageLocale': checkpoint.languageLocale,
      'rate': checkpoint.rate,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> clear({
    required String userEmail,
    required String documentKey,
    required int pageNumber,
  }) async {
    await _document(
      userEmail: userEmail,
      documentKey: documentKey,
      pageNumber: pageNumber,
    ).delete();
  }

  DocumentReference<Map<String, dynamic>> _document({
    required String userEmail,
    required String documentKey,
    required int pageNumber,
  }) {
    final identity = '$userEmail|$documentKey|$pageNumber';
    final documentId = base64Url.encode(utf8.encode(identity));

    return _firestore.collection('reader_narration_progress').doc(documentId);
  }
}

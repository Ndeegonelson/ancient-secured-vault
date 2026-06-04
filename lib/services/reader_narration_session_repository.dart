import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'reader_narration_session_tracker.dart';

class ReaderNarrationSessionRepository {
  ReaderNarrationSessionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> save({
    required String userEmail,
    required String readerSessionId,
    required String documentKey,
    required String pdfTitle,
    required String storagePath,
    required ReaderNarrationSessionSummary summary,
  }) async {
    if (!summary.hasActivity) return;

    final data = <String, dynamic>{
      'userEmail': userEmail,
      'readerSessionId': readerSessionId,
      'documentKey': documentKey,
      'pdfTitle': pdfTitle,
      'listeningSeconds': summary.listeningSeconds,
      'pagesNarrated': summary.pagesNarrated,
      'completedPages': summary.completedPages,
      'pageProgress': {
        for (final entry in summary.pageProgress.entries)
          entry.key.toString(): entry.value,
      },
      'highestProgressPercent': summary.highestProgressPercent,
      'selectedPassagesStarted': summary.selectedPassagesStarted,
      'selectedPassagesCompleted': summary.selectedPassagesCompleted,
      'startedAt': Timestamp.fromDate(summary.startedAt),
      'finished': summary.finished,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (storagePath.trim().isNotEmpty) {
      data['storagePath'] = storagePath;
    }
    if (summary.finished) {
      data['finishedAt'] = FieldValue.serverTimestamp();
    }

    await _document(
      userEmail,
      readerSessionId,
    ).set(data, SetOptions(merge: true));
  }

  DocumentReference<Map<String, dynamic>> _document(
    String userEmail,
    String readerSessionId,
  ) {
    final identity = '${userEmail.trim().toLowerCase()}|$readerSessionId';
    final documentId = base64Url.encode(utf8.encode(identity));

    return _firestore.collection('reader_narration_sessions').doc(documentId);
  }
}

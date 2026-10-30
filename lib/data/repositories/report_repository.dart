import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'user_repository.dart';
import 'video_repository.dart';

/// Why a video is reported (the same list is in firestore.rules).
const Map<String, String> reportReasons = {
  'sexual': 'Sexual content',
  'violent': 'Violent or repulsive content',
  'hateful': 'Hateful or abusive content',
  'harassment': 'Harassment or bullying',
  'harmful': 'Harmful or dangerous acts',
  'misinformation': 'Misinformation',
  'spam': 'Spam or misleading',
  'rights': 'Infringes my rights',
  'other': 'Something else',
};

/// Reports at `reports/{videoId}_{uid}`: one per person per video.
/// Nobody reviews them inside the app; you read them in the Firebase
/// console (Firestore Database → reports).
class ReportRepository {
  ReportRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  DocumentReference<Map<String, dynamic>> _doc(String videoId) =>
      _db.collection('reports').doc(reportId(videoId, _uid));

  /// Did I report this video already?
  Future<bool> hasReported(String videoId) async =>
      (await _doc(videoId).get()).exists;

  Future<void> report({
    required String videoId,
    required String reason,
    required String details,
  }) {
    return _doc(videoId).set({
      'reporterUid': _uid,
      'videoId': videoId,
      'reason': reason,
      'details': details.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

String reportId(String videoId, String uid) => '${videoId}_$uid';

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ReportRepository(
    ref.watch(firestoreProvider),
    ref.watch(currentUidProvider),
  ),
);

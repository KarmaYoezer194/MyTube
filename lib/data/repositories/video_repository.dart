import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/video.dart';

/// The Firestore database. A provider (instead of using
/// FirebaseFirestore.instance everywhere) keeps the data layer in one place.
final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

/// Everything the app reads from the `videos` collection goes through here.
/// Screens never talk to Firestore directly.
class VideoRepository {
  VideoRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _videos =>
      _db.collection('videos');

  /// All videos and Shorts, newest first. It's a Stream, so the list updates
  /// by itself when something changes (e.g. a new upload).
  ///
  /// We filter (Shorts, categories) in the app instead of in the query,
  /// because that needs no extra Firestore indexes and the demo has few
  /// videos.
  Stream<List<Video>> watchAllVideos() {
    return _videos
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Video.fromFirestore).toList());
  }

  /// Saves the real length, measured by the player the first time a video
  /// loads. (The security rules let anyone change this one field.)
  Future<void> updateDuration(String id, int seconds) {
    return _videos.doc(id).update({'durationSeconds': seconds});
  }

  /// +1 view. `increment` adds on the server, so two people watching at
  /// the same moment both count.
  Future<void> incrementViews(String id) {
    return _videos.doc(id).update({'views': FieldValue.increment(1)});
  }

  /// The uploader changes their video's details in the Studio. The rules
  /// only allow these fields, and only for the uploader.
  Future<void> updateDetails(
    String id, {
    required String title,
    required String description,
    required String category,
    required String visibility,
    String? thumbnailUrl,
  }) {
    return _videos.doc(id).update({
      'title': title,
      'description': description,
      'category': category,
      'visibility': visibility,
      'thumbnailUrl': ?thumbnailUrl,
    });
  }

  /// Deletes the video from MyTube (Firestore only). The file in
  /// Cloudinary stays: deleting it needs the API secret, which must never
  /// be in the app, so the uploader deletes it in the Cloudinary console.
  Future<void> deleteVideo(String id) => _videos.doc(id).delete();

  /// One video, live. Emits null if it doesn't exist.
  Stream<Video?> watchVideo(String id) {
    return _videos
        .doc(id)
        .snapshots()
        .map((doc) => doc.exists ? Video.fromFirestore(doc) : null);
  }
}

final videoRepositoryProvider = Provider<VideoRepository>(
  (ref) => VideoRepository(ref.watch(firestoreProvider)),
);

/// Live list of every video (long + Shorts), newest first.
final allVideosProvider = StreamProvider<List<Video>>(
  (ref) => ref.watch(videoRepositoryProvider).watchAllVideos(),
);

/// Live single video, e.g. `ref.watch(videoProvider('sintel'))`.
final videoProvider = StreamProvider.family<Video?, String>(
  (ref, id) => ref.watch(videoRepositoryProvider).watchVideo(id),
);

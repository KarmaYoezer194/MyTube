import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

  /// How many of the newest videos the app keeps loaded (the "catalog"
  /// used for Shorts, recommendations, Up next and search suggestions).
  /// Capped so the cost stays the same however many videos there are;
  /// older videos are looked up by id when needed ([getVideosByIds]).
  static const int catalogSize = 200;

  /// The newest [catalogSize] videos and Shorts, live (new uploads, views
  /// and likes update by themselves).
  Stream<List<Video>> watchAllVideos() {
    return _videos
        .orderBy('createdAt', descending: true)
        .limit(catalogSize)
        .snapshots()
        .map((snapshot) {
          final videos = snapshot.docs.map(Video.fromFirestore).toList();
          _fillMissingKeywords(videos);
          return videos;
        });
  }

  /// Videos from before Phase 18 have no search keywords. The first person
  /// who loads one fills them in, once (the rules allow adding just this
  /// field while it is missing).
  void _fillMissingKeywords(List<Video> videos) {
    for (final video in videos) {
      if (video.hasKeywords || !_keywordsFilled.add(video.id)) continue;
      _videos
          .doc(video.id)
          .update({'keywords': video.keywords})
          .catchError((Object e) => debugPrint('VIDEO keywords: $e'));
    }
  }

  static final _keywordsFilled = <String>{};

  /// Videos already fetched by id this session (older than the catalog).
  static final _byIdCache = <String, Video?>{};

  /// Videos by id, for lists that may hold videos older than the catalog
  /// (history, playlists, liked...). One query per 30 ids; each id is only
  /// fetched once per session. Deleted videos are left out.
  Future<Map<String, Video>> getVideosByIds(Iterable<String> ids) async {
    final missing = {
      for (final id in ids)
        if (!_byIdCache.containsKey(id)) id,
    }.toList();
    for (var i = 0; i < missing.length; i += 30) {
      final chunk = missing.sublist(
        i,
        i + 30 > missing.length ? missing.length : i + 30,
      );
      final snapshot = await _videos
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final id in chunk) {
        _byIdCache[id] = null; // Deleted unless found below.
      }
      for (final doc in snapshot.docs) {
        _byIdCache[doc.id] = Video.fromFirestore(doc);
      }
    }
    return {for (final id in ids) id: ?_byIdCache[id]};
  }

  /// My uploads (videos and Shorts, unlisted too), newest first, live.
  Stream<List<Video>> watchUploadsBy(String uid) {
    return _videos
        .where('uploaderUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(catalogSize)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Video.fromFirestore).toList());
  }

  // ---------------- Page-by-page lists (Discovery) ----------------

  /// Home: public long videos, newest first. [category] null = all;
  /// [since] = only videos uploaded after it ("Recently uploaded").
  Query<Map<String, dynamic>> homeQuery({String? category, DateTime? since}) {
    var query = _videos
        .where('visibility', isEqualTo: 'public')
        .where('isShort', isEqualTo: false);
    if (category != null) query = query.where('category', isEqualTo: category);
    if (since != null) {
      query = query.where(
        'createdAt',
        isGreaterThan: Timestamp.fromDate(since),
      );
    }
    return query.orderBy('createdAt', descending: true);
  }

  /// Explore / Trending: public long videos, most viewed first.
  Query<Map<String, dynamic>> trendingQuery({String? category}) {
    var query = _videos
        .where('visibility', isEqualTo: 'public')
        .where('isShort', isEqualTo: false);
    if (category != null) query = query.where('category', isEqualTo: category);
    return query.orderBy('views', descending: true);
  }

  /// Search: public videos with a word starting with [term]. [shorts]
  /// null = videos and Shorts. [byViews] sorts by views, else newest first.
  Query<Map<String, dynamic>> searchQuery(
    String term, {
    bool? shorts,
    bool byViews = false,
  }) {
    var query = _videos
        .where('keywords', arrayContains: term)
        .where('visibility', isEqualTo: 'public');
    if (shorts != null) query = query.where('isShort', isEqualTo: shorts);
    return query.orderBy(byViews ? 'views' : 'createdAt', descending: true);
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
    required List<String> keywords,
    String? thumbnailUrl,
  }) {
    return _videos.doc(id).update({
      'title': title,
      'description': description,
      'category': category,
      'visibility': visibility,
      'keywords': keywords,
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

/// The newest [VideoRepository.catalogSize] videos (long + Shorts),
/// newest first, live. (The name is older than the cap.)
final allVideosProvider = StreamProvider<List<Video>>(
  (ref) => ref.watch(videoRepositoryProvider).watchAllVideos(),
);

/// Live single video, e.g. `ref.watch(videoProvider('sintel'))`.
final videoProvider = StreamProvider.family<Video?, String>(
  (ref, id) => ref.watch(videoRepositoryProvider).watchVideo(id),
);

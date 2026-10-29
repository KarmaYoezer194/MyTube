import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../models/comment.dart';
import 'user_repository.dart';
import 'video_repository.dart';

/// Comments live at `videos/{videoId}/comments/{commentId}`.
/// Which comments I liked: `users/{uid}/commentLikes/{videoId}_{commentId}`.
class CommentRepository {
  CommentRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  CollectionReference<Map<String, dynamic>> _comments(String videoId) =>
      _db.collection('videos').doc(videoId).collection('comments');

  /// All comments of a video, live. Sorting (Top / Newest) is done in the
  /// app, so a comment you just posted shows up immediately, even before
  /// the server has given it a time.
  Stream<List<Comment>> watchComments(String videoId) {
    return _comments(videoId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Comment.fromFirestore).toList());
  }

  /// Posts a comment. Firestore shows it in the stream right away (before
  /// the server confirms), which is why posting feels instant.
  Future<void> addComment({
    required String videoId,
    required AppUser author,
    required String text,
  }) {
    final comment = Comment(
      id: '',
      uid: author.uid,
      displayName: author.displayName,
      handle: author.handle,
      avatarUrl: author.avatarUrl,
      text: text,
      likes: 0,
      createdAt: DateTime.now(),
    );
    return _comments(videoId).add(comment.toFirestore());
  }

  // ---------------- Liking comments ----------------

  DocumentReference<Map<String, dynamic>> _likeDoc(
    String videoId,
    String commentId,
  ) {
    return _db
        .collection('users')
        .doc(_uid)
        .collection('commentLikes')
        .doc('${videoId}_$commentId');
  }

  /// Ids of the comments on this video that I liked.
  Stream<Set<String>> watchLikedCommentIds(String videoId) {
    return _db
        .collection('users')
        .doc(_uid)
        .collection('commentLikes')
        .where('videoId', isEqualTo: videoId)
        .snapshots()
        .map((snapshot) => {
              for (final doc in snapshot.docs) doc.data()['commentId'] as String,
            });
  }

  /// Like / unlike a comment. My "like" and the comment's counter change
  /// together in one batch.
  Future<void> setCommentLiked({
    required String videoId,
    required String commentId,
    required bool liked,
  }) {
    final batch = _db.batch();
    final like = _likeDoc(videoId, commentId);
    if (liked) {
      batch.set(like, {
        'videoId': videoId,
        'commentId': commentId,
        'likedAt': FieldValue.serverTimestamp(),
      });
    } else {
      batch.delete(like);
    }
    batch.update(_comments(videoId).doc(commentId), {
      'likes': FieldValue.increment(liked ? 1 : -1),
    });
    return batch.commit();
  }
}

final commentRepositoryProvider = Provider<CommentRepository>(
  (ref) => CommentRepository(
    ref.watch(firestoreProvider),
    ref.watch(currentUidProvider),
  ),
);

/// Live comments of a video (not sorted).
final commentsProvider = StreamProvider.family<List<Comment>, String>(
  (ref, videoId) =>
      ref.watch(commentRepositoryProvider).watchComments(videoId),
);

/// Ids of the comments on this video that I liked.
final likedCommentIdsProvider = StreamProvider.family<Set<String>, String>(
  (ref, videoId) =>
      ref.watch(commentRepositoryProvider).watchLikedCommentIds(videoId),
);

/// Top = most liked first; Newest = most recent first.
enum CommentSort { top, newest }

List<Comment> sortComments(List<Comment> comments, CommentSort sort) {
  final sorted = [...comments];
  sorted.sort((a, b) {
    if (sort == CommentSort.top && a.likes != b.likes) {
      return b.likes.compareTo(a.likes);
    }
    return b.createdAt.compareTo(a.createdAt);
  });
  return sorted;
}

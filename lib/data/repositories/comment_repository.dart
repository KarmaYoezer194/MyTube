import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../models/comment.dart';
import 'user_repository.dart';
import 'video_repository.dart';

/// Top = most liked first; Newest = most recent first.
enum CommentSort { top, newest }

/// Comments live at `videos/{videoId}/comments/{commentId}`, replies at
/// `.../comments/{commentId}/replies/{replyId}`.
/// Which comments I liked: `users/{uid}/commentLikes/{videoId}_{id}`.
///
/// Counters (no server, so the app keeps them and the rules check them):
/// - `videos/{id}.commentCount`: comments + replies.
/// - `comments/{id}.replyCount`: replies of that comment.
/// Every post / delete changes the counter in the same batch, and also
/// writes which comment it was (`lastCommentId` / `lastReplyId`) so the
/// rules can check that the comment really was added or removed.
class CommentRepository {
  CommentRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  /// Videos whose missing comment counter we already tried to fill in.
  static final _countChecked = <String>{};

  DocumentReference<Map<String, dynamic>> _video(String videoId) =>
      _db.collection('videos').doc(videoId);

  CollectionReference<Map<String, dynamic>> _comments(String videoId) =>
      _video(videoId).collection('comments');

  CollectionReference<Map<String, dynamic>> _replies(
    String videoId,
    String commentId,
  ) => _comments(videoId).doc(commentId).collection('replies');

  DocumentReference<Map<String, dynamic>> _doc(
    String videoId,
    Comment comment,
  ) => comment.isReply
      ? _replies(videoId, comment.parentId).doc(comment.id)
      : _comments(videoId).doc(comment.id);

  // ---------------- Reading ----------------

  /// The comments of a video (not replies), for page-by-page loading.
  /// "Top" needs the composite index in firestore.indexes.json.
  Query<Map<String, dynamic>> commentsQuery(String videoId, CommentSort sort) {
    final comments = _comments(videoId);
    return switch (sort) {
      CommentSort.top =>
        comments
            .orderBy('likes', descending: true)
            .orderBy('createdAt', descending: true),
      CommentSort.newest => comments.orderBy('createdAt', descending: true),
    };
  }

  /// The replies of one comment, oldest first (like YouTube).
  Query<Map<String, dynamic>> repliesQuery(String videoId, String commentId) =>
      _replies(videoId, commentId).orderBy('createdAt');

  /// One comment (e.g. the pinned one), or null if it was deleted.
  Future<Comment?> getComment(String videoId, String commentId) async {
    final doc = await _comments(videoId).doc(commentId).get();
    return doc.exists ? Comment.fromFirestore(doc) : null;
  }

  /// The most liked comment (shown on the watch page's comments card).
  Future<Comment?> topComment(String videoId) async {
    final snapshot = await commentsQuery(
      videoId,
      CommentSort.top,
    ).limit(1).get();
    return snapshot.docs.isEmpty
        ? null
        : Comment.fromFirestore(snapshot.docs.first);
  }

  /// Videos from before Phase 14 have no `commentCount`. The first person
  /// who opens one counts its comments once (a cheap count query, not a
  /// read of every comment) and saves the number. The rules only allow
  /// this while the field is missing.
  Future<void> fillMissingCommentCount(String videoId) async {
    if (!_countChecked.add(videoId)) return;
    try {
      final result = await _comments(videoId).count().get();
      // Replies didn't exist before the counter, so this is all of them.
      await _video(videoId).update({'commentCount': result.count ?? 0});
    } catch (error) {
      // Someone else filled it in first, or we're offline. Not important.
      debugPrint('COMMENTS: could not fill in the comment count: $error');
    }
  }

  // ---------------- Writing ----------------

  Comment _newComment(AppUser author, String text, {String parentId = ''}) {
    return Comment(
      id: '',
      uid: author.uid,
      displayName: author.displayName,
      handle: author.handle,
      avatarUrl: author.avatarUrl,
      text: text,
      likes: 0,
      createdAt: DateTime.now(),
      parentId: parentId,
    );
  }

  /// Posts a comment and returns it, so the screen can show it at once.
  Future<Comment> addComment({
    required String videoId,
    required AppUser author,
    required String text,
  }) async {
    final doc = _comments(videoId).doc();
    final comment = _newComment(author, text);
    final batch = _db.batch()
      ..set(doc, comment.toFirestore())
      ..update(_video(videoId), {
        'commentCount': FieldValue.increment(1),
        'lastCommentId': doc.id,
        'lastReplyId': '',
      });
    await batch.commit();
    return Comment.fromMap(doc.id, {
      ...comment.toFirestore(),
      'createdAt': null,
    });
  }

  /// Replies to the comment [parentId] (never to a reply: replies stay one
  /// level deep) and returns the reply.
  Future<Comment> addReply({
    required String videoId,
    required String parentId,
    required AppUser author,
    required String text,
  }) async {
    final doc = _replies(videoId, parentId).doc();
    final reply = _newComment(author, text, parentId: parentId);
    final batch = _db.batch()
      ..set(doc, reply.toFirestore())
      ..update(_comments(videoId).doc(parentId), {
        'replyCount': FieldValue.increment(1),
        'lastReplyId': doc.id,
      })
      ..update(_video(videoId), {
        'commentCount': FieldValue.increment(1),
        'lastCommentId': parentId,
        'lastReplyId': doc.id,
      });
    await batch.commit();
    return Comment.fromMap(doc.id, {
      ...reply.toFirestore(),
      'createdAt': null,
    }, parentId: parentId);
  }

  /// Changes the text of my own comment or reply (shows "(edited)").
  Future<void> editComment({
    required String videoId,
    required Comment comment,
    required String text,
  }) {
    return _doc(videoId, comment).update({
      'text': text,
      'edited': true,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes my own comment (with all its replies) or reply, and lowers
  /// the counters. [knownCommentCount] / [knownReplyCount] are the numbers
  /// on screen, used so a counter never goes below 0.
  Future<void> deleteComment({
    required String videoId,
    required Comment comment,
    int? knownCommentCount,
    int? knownReplyCount,
  }) async {
    final batch = _db.batch();
    if (comment.isReply) {
      batch
        ..delete(_doc(videoId, comment))
        ..update(_comments(videoId).doc(comment.parentId), {
          'replyCount': counterChange(knownReplyCount, -1),
          'lastReplyId': comment.id,
        })
        ..update(_video(videoId), {
          'commentCount': counterChange(knownCommentCount, -1),
          'lastCommentId': comment.parentId,
          'lastReplyId': comment.id,
        });
    } else {
      // The rules check the counter against the SAVED reply count, so read
      // it fresh (someone may have replied since the list loaded).
      final commentDoc = _comments(videoId).doc(comment.id);
      final fresh = await commentDoc.get();
      if (!fresh.exists) return; // Already gone.
      final replyCount = Comment.fromFirestore(fresh).replyCount;
      // Its replies go too (a batch holds up to 500 writes).
      if (replyCount > 0) {
        final replies = await _replies(videoId, comment.id).limit(400).get();
        for (final reply in replies.docs) {
          batch.delete(reply.reference);
        }
      }
      batch
        ..delete(commentDoc)
        ..update(_video(videoId), {
          'commentCount': counterChange(knownCommentCount, -1 - replyCount),
          'lastCommentId': comment.id,
          'lastReplyId': '',
        });
    }
    await batch.commit();
  }

  /// The video's uploader gives (or takes back) a heart.
  Future<void> setHearted({
    required String videoId,
    required Comment comment,
    required bool hearted,
  }) {
    return _doc(videoId, comment).update({'hearted': hearted});
  }

  /// The video's uploader pins a comment to the top ('' = unpin).
  /// Only one comment can be pinned: pinning another one replaces it.
  Future<void> setPinned({required String videoId, required String commentId}) {
    return _video(videoId).update({'pinnedCommentId': commentId});
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

  /// Ids of the comments and replies on this video that I liked.
  Stream<Set<String>> watchLikedCommentIds(String videoId) {
    return _db
        .collection('users')
        .doc(_uid)
        .collection('commentLikes')
        .where('videoId', isEqualTo: videoId)
        .snapshots()
        .map(
          (snapshot) => {
            for (final doc in snapshot.docs) doc.data()['commentId'] as String,
          },
        );
  }

  /// Like / unlike a comment or reply. My "like" and its counter change
  /// together in one batch.
  Future<void> setCommentLiked({
    required String videoId,
    required Comment comment,
    required bool liked,
  }) {
    final batch = _db.batch();
    final like = _likeDoc(videoId, comment.id);
    if (liked) {
      batch.set(like, {
        'videoId': videoId,
        'commentId': comment.id,
        if (comment.isReply) 'parentId': comment.parentId,
        'likedAt': FieldValue.serverTimestamp(),
      });
    } else {
      batch.delete(like);
    }
    batch.update(_doc(videoId, comment), {
      'likes': FieldValue.increment(liked ? 1 : -1),
    });
    return batch.commit();
  }
}

/// How to change a counter by [change]: normally "add [change]" (safe when
/// several people post at once), but if the number we know would go below
/// 0, save exactly 0 instead (the rules allow that too).
Object counterChange(int? known, int change) =>
    exactCountOrNull(known, change) ?? FieldValue.increment(change);

/// 0 when [known] + [change] would be negative, otherwise null.
int? exactCountOrNull(int? known, int change) =>
    known != null && known + change < 0 ? 0 : null;

/// Text to start a reply with: replying to a reply mentions its author
/// (the reply still goes into the same thread).
String replyPrefill(Comment target) =>
    target.isReply ? '${target.handle} ' : '';

final commentRepositoryProvider = Provider<CommentRepository>(
  (ref) => CommentRepository(
    ref.watch(firestoreProvider),
    ref.watch(currentUidProvider),
  ),
);

/// Ids of the comments on this video that I liked (live).
final likedCommentIdsProvider = StreamProvider.family<Set<String>, String>(
  (ref, videoId) =>
      ref.watch(commentRepositoryProvider).watchLikedCommentIds(videoId),
);

/// Which comment to show on the watch page's card. The count and pinned id
/// are part of the key, so the card refreshes when they change.
typedef TopCommentArg = ({String videoId, int count, String pinnedId});

/// The pinned comment if there is one, otherwise the most liked one.
final topCommentProvider = FutureProvider.autoDispose
    .family<Comment?, TopCommentArg>((ref, arg) async {
      if (arg.count == 0 && arg.pinnedId.isEmpty) return null;
      final repository = ref.watch(commentRepositoryProvider);
      if (arg.pinnedId.isNotEmpty) {
        final pinned = await repository.getComment(arg.videoId, arg.pinnedId);
        if (pinned != null) return pinned;
      }
      return repository.topComment(arg.videoId);
    });

typedef PinnedCommentArg = ({String videoId, String commentId});

/// The pinned comment of a video (null if it was deleted).
final pinnedCommentProvider = FutureProvider.autoDispose
    .family<Comment?, PinnedCommentArg>(
      (ref, arg) => ref
          .watch(commentRepositoryProvider)
          .getComment(arg.videoId, arg.commentId),
    );

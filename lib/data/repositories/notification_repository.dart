import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/channel.dart';
import '../models/video.dart';
import 'user_repository.dart';
import 'video_repository.dart';

/// In-app notifications at `users/{uid}/notifications/{id}`.
///
/// There is no server (free Spark plan, no Cloud Functions), so the app
/// that does something writes the notification into the other person's
/// folder itself, and the security rules check it is genuine:
/// - a new upload goes to the uploader's subscribers (up to
///   [maxUploadRecipients]), [chunkSize] per batch;
/// - a comment goes to the video's uploader;
/// - a reply goes to the author of the comment it answers.
class NotificationRepository {
  NotificationRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  /// How many notifications the list shows (and counts as unread).
  static const int listLimit = 50;

  /// Most subscribers one upload notifies (keeps the free write quota safe).
  static const int maxUploadRecipients = 100;

  /// Notifications per batch. The rules check each one against the
  /// receiver's subscription; a batch may do 20 such checks in total.
  static const int chunkSize = 15;

  CollectionReference<Map<String, dynamic>> _inbox(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');

  // ---------------- My notifications ----------------

  /// My newest notifications (live).
  Stream<List<AppNotification>> watchMine() {
    return _inbox(_uid)
        .orderBy('createdAt', descending: true)
        .limit(listLimit)
        .snapshots()
        .map(
          (s) => [for (final doc in s.docs) AppNotification.fromFirestore(doc)],
        );
  }

  Future<void> setRead(String id, {required bool read}) =>
      _inbox(_uid).doc(id).update({'read': read});

  /// Marks these as read in one batch.
  Future<void> markAllRead(Iterable<String> ids) async {
    final batch = _db.batch();
    for (final id in ids) {
      batch.update(_inbox(_uid).doc(id), {'read': true});
    }
    await batch.commit();
  }

  Future<void> remove(String id) => _inbox(_uid).doc(id).delete();

  // ---------------- Sending ----------------

  AppNotification _draft({
    required String id,
    required NotificationType type,
    required AppUser me,
    required Video video,
    String commentId = '',
    String replyId = '',
    String text = '',
  }) {
    return AppNotification(
      id: id,
      type: type,
      fromUid: me.uid,
      fromName: me.displayName,
      fromAvatarUrl: me.avatarUrl,
      fromAvatarColor: me.avatarColor,
      videoId: video.id,
      videoTitle: video.title,
      thumbnailUrl: video.thumbnailUrl,
      isShort: video.isShort,
      commentId: commentId,
      replyId: replyId,
      text: text,
      read: false,
      createdAt: DateTime.now(),
    );
  }

  /// Tells my subscribers about my new public upload [video].
  /// Returns how many were notified.
  Future<int> notifySubscribersOfUpload({
    required Video video,
    required AppUser me,
  }) async {
    final subscriptions = await _db
        .collectionGroup('subscribed')
        .where('channelId', isEqualTo: Channel.idForUser(me.uid))
        .limit(maxUploadRecipients)
        .get();
    // users/{uid}/subscribed/{channelId} -> uid
    final receivers = [
      for (final doc in subscriptions.docs)
        if (doc.reference.parent.parent?.id case final uid?)
          if (uid != me.uid) uid,
    ];
    final notification = _draft(
      id: AppNotification.uploadId(video.id),
      type: NotificationType.upload,
      me: me,
      video: video,
    ).toFirestore();

    var sent = 0;
    for (final group in chunked(receivers, chunkSize)) {
      final batch = _db.batch();
      for (final uid in group) {
        batch.set(
          _inbox(uid).doc(AppNotification.uploadId(video.id)),
          notification,
        );
      }
      try {
        await batch.commit();
        sent += group.length;
      } catch (error) {
        // One bad group (e.g. someone unsubscribed a second ago) must not
        // stop the others.
        debugPrint('NOTIFY: an upload batch failed: $error');
      }
    }
    return sent;
  }

  /// Tells the video's uploader about my new comment.
  Future<void> notifyComment({
    required Video video,
    required AppUser me,
    required String commentId,
    required String text,
  }) {
    final id = AppNotification.commentNotificationId(commentId);
    return _inbox(video.uploaderUid)
        .doc(id)
        .set(
          _draft(
            id: id,
            type: NotificationType.comment,
            me: me,
            video: video,
            commentId: commentId,
            text: text,
          ).toFirestore(),
        );
  }

  /// Tells [commentAuthorUid] about my reply [replyId] to their comment.
  Future<void> notifyReply({
    required Video video,
    required AppUser me,
    required String commentAuthorUid,
    required String commentId,
    required String replyId,
    required String text,
  }) {
    final id = AppNotification.replyNotificationId(replyId);
    return _inbox(commentAuthorUid)
        .doc(id)
        .set(
          _draft(
            id: id,
            type: NotificationType.reply,
            me: me,
            video: video,
            commentId: commentId,
            replyId: replyId,
            text: text,
          ).toFirestore(),
        );
  }
}

/// Whether to send a notification to [receiverUid] at all: not to myself,
/// and not to the sample channels (owner 'seed').
bool shouldNotify({required String receiverUid, required String myUid}) =>
    receiverUid.isNotEmpty && receiverUid != myUid && receiverUid != 'seed';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(
    ref.watch(firestoreProvider),
    ref.watch(currentUidProvider),
  ),
);

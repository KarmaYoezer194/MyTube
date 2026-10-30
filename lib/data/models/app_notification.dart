import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum NotificationType { upload, comment, reply }

/// One in-app notification, stored at `users/{uid}/notifications/{id}`
/// (in the RECEIVER's folder; written by the sender's app, checked by the
/// rules).
///
/// The id says what it is about, so the same thing can't be sent twice:
/// `u_{videoId}`, `c_{commentId}` or `r_{replyId}`.
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.fromUid,
    required this.fromName,
    required this.fromAvatarUrl,
    required this.videoId,
    required this.videoTitle,
    required this.thumbnailUrl,
    required this.isShort,
    required this.commentId,
    required this.replyId,
    required this.text,
    required this.read,
    required this.createdAt,
    this.fromAvatarColor,
  });

  final String id;
  final NotificationType type;

  /// Who did it (uploaded, commented, replied).
  final String fromUid;
  final String fromName;
  final String fromAvatarUrl;
  final int? fromAvatarColor;

  final String videoId;
  final String videoTitle;
  final String thumbnailUrl;
  final bool isShort;

  /// The comment (for a reply: the comment it belongs to). '' for uploads.
  final String commentId;

  /// The reply. '' unless [type] is reply.
  final String replyId;

  /// The start of the comment / reply ('' for uploads).
  final String text;
  final bool read;
  final DateTime createdAt;

  /// Longest comment snippet saved in a notification.
  static const int maxText = 200;

  static String uploadId(String videoId) => 'u_$videoId';
  static String commentNotificationId(String commentId) => 'c_$commentId';
  static String replyNotificationId(String replyId) => 'r_$replyId';

  /// The line shown in the list.
  String get message => switch (type) {
    NotificationType.upload =>
      isShort
          ? '$fromName posted a new Short: $videoTitle'
          : '$fromName uploaded: $videoTitle',
    NotificationType.comment => '$fromName commented: "$text"',
    NotificationType.reply => '$fromName replied to your comment: "$text"',
  };

  factory AppNotification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => AppNotification.fromMap(doc.id, doc.data() ?? const {});

  factory AppNotification.fromMap(String id, Map<String, dynamic> data) {
    return AppNotification(
      id: id,
      type: NotificationType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => NotificationType.upload,
      ),
      fromUid: data['fromUid'] as String? ?? '',
      fromName: data['fromName'] as String? ?? '',
      fromAvatarUrl: data['fromAvatarUrl'] as String? ?? '',
      fromAvatarColor: (data['fromAvatarColor'] as num?)?.toInt(),
      videoId: data['videoId'] as String? ?? '',
      videoTitle: data['videoTitle'] as String? ?? '',
      thumbnailUrl: data['thumbnailUrl'] as String? ?? '',
      isShort: data['isShort'] as bool? ?? false,
      commentId: data['commentId'] as String? ?? '',
      replyId: data['replyId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      read: data['read'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Map for a NEW notification (unread, server time).
  Map<String, dynamic> toFirestore() => {
    'type': type.name,
    'fromUid': fromUid,
    'fromName': fromName,
    'fromAvatarUrl': fromAvatarUrl,
    'fromAvatarColor': ?fromAvatarColor,
    'videoId': videoId,
    'videoTitle': videoTitle,
    'thumbnailUrl': thumbnailUrl,
    'isShort': isShort,
    'commentId': commentId,
    'replyId': replyId,
    'text': snippet(text),
    'read': false,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

/// The first [AppNotification.maxText] characters, on one line.
String snippet(String text) {
  final oneLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return oneLine.length <= AppNotification.maxText
      ? oneLine
      : '${oneLine.substring(0, AppNotification.maxText - 1)}…';
}

/// The red badge text: "" for none, "1".."9", then "9+".
String badgeLabel(int unread) => switch (unread) {
  <= 0 => '',
  > 9 => '9+',
  _ => '$unread',
};

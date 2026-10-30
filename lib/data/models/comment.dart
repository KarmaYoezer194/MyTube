import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// One comment or reply.
///
/// - Comments: `videos/{videoId}/comments/{commentId}`
/// - Replies:  `videos/{videoId}/comments/{commentId}/replies/{replyId}`
///   (one level deep, like YouTube: a reply to a reply goes into the same
///   thread and starts with "@handle").
@immutable
class Comment {
  const Comment({
    required this.id,
    required this.uid,
    required this.displayName,
    required this.handle,
    required this.avatarUrl,
    required this.text,
    required this.likes,
    required this.createdAt,
    this.parentId = '',
    this.replyCount = 0,
    this.edited = false,
    this.hearted = false,
  });

  final String id;

  /// The user who wrote it.
  final String uid;
  final String displayName;

  /// Like "@karma-1234", shown above the comment text.
  final String handle;

  /// Empty string means "no picture": we show a colored letter avatar.
  final String avatarUrl;

  final String text;
  final int likes;
  final DateTime createdAt;

  /// For a reply: the id of the comment it belongs to. '' for comments.
  final String parentId;

  /// How many replies a comment has (always 0 for replies).
  final int replyCount;

  /// The author changed the text after posting: shows "(edited)".
  final bool edited;

  /// The video's uploader gave it a heart.
  final bool hearted;

  bool get isReply => parentId.isNotEmpty;

  /// Reads a comment or reply document. Whether it is a reply comes from
  /// where it is stored (inside a `replies` folder).
  factory Comment.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final folder = doc.reference.parent;
    final parentId = folder.id == 'replies' ? folder.parent?.id ?? '' : '';
    return Comment.fromMap(
      doc.id,
      doc.data() ?? const <String, dynamic>{},
      parentId: parentId,
    );
  }

  /// Every field has a safe default, so old or half-filled documents
  /// can't crash the app.
  factory Comment.fromMap(
    String id,
    Map<String, dynamic> data, {
    String parentId = '',
  }) {
    return Comment(
      id: id,
      uid: data['uid'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      handle: data['handle'] as String? ?? '',
      avatarUrl: data['avatarUrl'] as String? ?? '',
      text: data['text'] as String? ?? '',
      likes: (data['likes'] as num?)?.toInt() ?? 0,
      // Right after posting, the server time isn't known yet (null),
      // so we show "now" until Firestore fills it in.
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      parentId: parentId,
      replyCount: (data['replyCount'] as num?)?.toInt() ?? 0,
      edited: data['edited'] as bool? ?? false,
      hearted: data['hearted'] as bool? ?? false,
    );
  }

  /// Map for a NEW comment or reply. The time is set by the Firestore
  /// server so everyone's clock agrees. Only comments (not replies) have a
  /// reply counter.
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'displayName': displayName,
      'handle': handle,
      'avatarUrl': avatarUrl,
      'text': text,
      'likes': 0,
      if (!isReply) 'replyCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Comment copyWith({
    String? text,
    int? likes,
    int? replyCount,
    bool? edited,
    bool? hearted,
  }) {
    return Comment(
      id: id,
      uid: uid,
      displayName: displayName,
      handle: handle,
      avatarUrl: avatarUrl,
      text: text ?? this.text,
      likes: likes ?? this.likes,
      createdAt: createdAt,
      parentId: parentId,
      replyCount: replyCount ?? this.replyCount,
      edited: edited ?? this.edited,
      hearted: hearted ?? this.hearted,
    );
  }
}

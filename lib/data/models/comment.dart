import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// One comment, stored at `videos/{videoId}/comments/{commentId}`.
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

  factory Comment.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Comment(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      handle: data['handle'] as String? ?? '',
      avatarUrl: data['avatarUrl'] as String? ?? '',
      text: data['text'] as String? ?? '',
      likes: (data['likes'] as num?)?.toInt() ?? 0,
      // Right after posting, the server time isn't known yet (null),
      // so we show "now" until Firestore fills it in.
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Map for a NEW comment. The time is set by the Firestore server so
  /// everyone's clock agrees.
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'displayName': displayName,
      'handle': handle,
      'avatarUrl': avatarUrl,
      'text': text,
      'likes': likes,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

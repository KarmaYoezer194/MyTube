import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// A user profile, stored at `users/{uid}`.
///
/// Everyone is signed in anonymously. This document is only created the
/// first time someone comments or uploads (that's when we ask for a name).
@immutable
class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.handle,
    required this.avatarUrl,
    required this.createdAt,
  });

  final String uid;
  final String displayName;

  /// Like "@karma-1234".
  final String handle;

  /// Empty string means "no picture": we show a colored letter avatar.
  final String avatarUrl;

  final DateTime createdAt;

  /// First letter of the name, for the letter avatar.
  String get initial =>
      displayName.trim().isEmpty ? '?' : displayName.trim()[0].toUpperCase();

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AppUser(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? '',
      handle: data['handle'] as String? ?? '',
      avatarUrl: data['avatarUrl'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'handle': handle,
      'avatarUrl': avatarUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

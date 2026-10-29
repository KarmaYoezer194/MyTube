import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme/avatar_colors.dart';

/// A user profile, stored at `users/{uid}`.
///
/// Only people with a real account (email or Google) have one. It is
/// created when they sign up / sign in. Guests (anonymous users) don't.
@immutable
class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.handle,
    required this.avatarUrl,
    required this.avatarColor,
    required this.createdAt,
  });

  final String uid;
  final String displayName;

  /// Like "@karmayoezer4821".
  final String handle;

  /// Empty string means "no picture": we show a colored letter avatar.
  final String avatarUrl;

  /// Color of the letter avatar, saved as a number (e.g. 0xFFD81B60).
  final int avatarColor;

  final DateTime createdAt;

  Color get avatarColorValue => Color(avatarColor);

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final name = data['displayName'] as String? ?? '';
    return AppUser(
      uid: doc.id,
      displayName: name,
      handle: data['handle'] as String? ?? '',
      avatarUrl: data['avatarUrl'] as String? ?? '',
      // Older profiles have no avatarColor yet: use the name's color.
      avatarColor:
          (data['avatarColor'] as num?)?.toInt() ??
          avatarColorFor(name).toARGB32(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'handle': handle,
      'avatarUrl': avatarUrl,
      'avatarColor': avatarColor,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

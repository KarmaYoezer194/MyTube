import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme/avatar_colors.dart';
import '../../core/utils/search_keywords.dart';
import 'app_user.dart';
import 'video.dart';

/// A channel, stored at `channels/{channelId}`.
///
/// - The 6 sample channels have ids like `blender-foundation` and owner
///   `seed`.
/// - Every account has one channel with the id `user-{uid}` ([idForUser]).
///   Its name, @handle and avatar color are the same as the profile in
///   `users/{uid}` (the rules keep them in sync).
@immutable
class Channel {
  const Channel({
    required this.id,
    required this.name,
    required this.handle,
    required this.description,
    required this.bannerUrl,
    required this.avatarUrl,
    required this.avatarColor,
    required this.subscriberCount,
    required this.ownerUid,
    required this.createdAt,
    this.hasKeywords = true,
  });

  final String id;
  final String name;

  /// Like "@karmayoezer4821".
  final String handle;

  /// The About text (up to [maxDescriptionLength] characters).
  final String description;

  /// Wide picture at the top of the channel page. Empty = no banner.
  final String bannerUrl;

  /// Empty = a colored letter avatar in [avatarColor].
  final String avatarUrl;
  final int avatarColor;

  /// Kept up to date with +1 / -1 when people (un)subscribe.
  final int subscriberCount;

  /// The account that owns it, or `seed` for the sample channels.
  final String ownerUid;
  final DateTime createdAt;

  static const int maxNameLength = 50;
  static const int maxDescriptionLength = 1000;

  /// The channel id of an account.
  static String idForUser(String uid) => 'user-$uid';

  bool get isSeed => ownerUid == 'seed';
  Color get avatarColorValue => Color(avatarColor);

  /// Reads a channel from its Firestore fields. Every field has a safe
  /// default, so a half-filled document can't crash the app.
  factory Channel.fromMap(String id, Map<String, dynamic> data) {
    final name = data['name'] as String? ?? '';
    return Channel(
      id: id,
      name: name,
      handle: data['handle'] as String? ?? '',
      description: data['description'] as String? ?? '',
      bannerUrl: data['bannerUrl'] as String? ?? '',
      avatarUrl: data['avatarUrl'] as String? ?? '',
      avatarColor:
          (data['avatarColor'] as num?)?.toInt() ??
          avatarColorFor(name).toARGB32(),
      subscriberCount: (data['subscriberCount'] as num?)?.toInt() ?? 0,
      ownerUid: data['ownerUid'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hasKeywords: data['keywords'] is List,
    );
  }

  /// false for channels from before Phase 18 (no search keywords yet).
  final bool hasKeywords;

  /// Search keywords for the current name and @handle.
  List<String> get keywords => channelKeywords(name: name, handle: handle);

  factory Channel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Channel.fromMap(doc.id, doc.data() ?? const {});

  /// A stand-in made from one of the channel's videos, for channels that
  /// don't have a `channels` document yet (uploads made before Phase 13).
  factory Channel.fromVideo(Video video) {
    final uid = video.uploaderUid;
    return Channel(
      id: video.channelId,
      name: video.channelName,
      handle: '',
      description: '',
      bannerUrl: '',
      avatarUrl: video.channelAvatarUrl,
      avatarColor:
          video.channelAvatarColor ??
          avatarColorFor(video.channelName).toARGB32(),
      subscriberCount: video.subscriberCount,
      ownerUid: uid,
      createdAt: video.createdAt,
    );
  }

  /// A stand-in made from an account's public profile, for accounts that
  /// don't have a channel document yet.
  factory Channel.fromProfile(AppUser user) {
    return Channel(
      id: idForUser(user.uid),
      name: user.displayName,
      handle: user.handle,
      description: '',
      bannerUrl: '',
      avatarUrl: user.avatarUrl,
      avatarColor: user.avatarColor,
      subscriberCount: 0,
      ownerUid: user.uid,
      createdAt: user.createdAt,
    );
  }

  /// Fields for a NEW channel document (server time).
  Map<String, dynamic> toNewFirestore() {
    return {
      'name': name,
      'handle': handle,
      'description': description,
      'bannerUrl': bannerUrl,
      'avatarUrl': avatarUrl,
      'avatarColor': avatarColor,
      'subscriberCount': subscriberCount,
      'ownerUid': ownerUid,
      'createdAt': FieldValue.serverTimestamp(),
      'keywords': keywords,
    };
  }
}

/// Turns what someone typed into a handle: "@Karma.Y" -> "@karma.y".
/// Spaces are removed; the result still has to pass [handleProblem].
String normalizeHandle(String input) {
  var text = input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  while (text.startsWith('@')) {
    text = text.substring(1);
  }
  return '@$text';
}

/// null if [handle] (already normalized, with '@') is valid, otherwise the
/// reason. Same rule as in firestore.rules: 3-30 of a-z, 0-9, '.', '_', '-'.
String? handleProblem(String handle) {
  final body = handle.startsWith('@') ? handle.substring(1) : handle;
  if (body.length < 3) return 'Your handle needs at least 3 characters.';
  if (body.length > 30) return 'Your handle can have up to 30 characters.';
  if (!RegExp(r'^[a-z0-9._-]+$').hasMatch(body)) {
    return 'Use only letters, numbers, periods, dashes or underscores.';
  }
  return null;
}

/// null if the channel name is fine, otherwise the reason.
String? channelNameProblem(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'Please enter a name.';
  if (trimmed.length > Channel.maxNameLength) {
    return 'Names can have up to ${Channel.maxNameLength} characters.';
  }
  return null;
}

/// Splits [items] into lists of at most [size] (Firestore's `whereIn`
/// accepts at most 30 values).
List<List<T>> chunked<T>(List<T> items, int size) {
  return [
    for (var i = 0; i < items.length; i += size)
      items.sublist(i, i + size > items.length ? items.length : i + size),
  ];
}

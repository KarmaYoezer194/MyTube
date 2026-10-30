import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// A playlist, stored at `playlists/{playlistId}`:
/// ownerUid, channelId ('user-{uid}'), title, visibility ('public' or
/// 'private'), videoIds (in playlist order), createdAt, updatedAt.
///
/// The video ids live inside the playlist document, so opening a playlist
/// is ONE read and reordering it is ONE write.
@immutable
class Playlist {
  const Playlist({
    required this.id,
    required this.ownerUid,
    required this.channelId,
    required this.title,
    required this.visibility,
    required this.videoIds,
    required this.updatedAt,
  });

  /// Most videos one playlist can hold (keeps the document small).
  static const int maxVideos = 200;

  /// Ids of the two built-in playlists (like YouTube's "LL" and "WL").
  static const String likedId = 'LL';
  static const String watchLaterId = 'WL';

  static bool isBuiltIn(String id) => id == likedId || id == watchLaterId;

  final String id;
  final String ownerUid;
  final String channelId;
  final String title;

  /// 'public' (shown on your channel) or 'private' (only you).
  final String visibility;
  final List<String> videoIds;
  final DateTime updatedAt;

  bool get isPrivate => visibility != 'public';
  bool get isFull => videoIds.length >= maxVideos;
  bool contains(String videoId) => videoIds.contains(videoId);

  factory Playlist.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Playlist.fromMap(doc.id, doc.data() ?? const <String, dynamic>{});

  /// Every field has a safe default, so a half-filled document can't crash
  /// the app.
  factory Playlist.fromMap(String id, Map<String, dynamic> data) {
    return Playlist(
      id: id,
      ownerUid: data['ownerUid'] as String? ?? '',
      channelId: data['channelId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      // Anything unexpected counts as private (the safe choice).
      visibility: data['visibility'] == 'public' ? 'public' : 'private',
      videoIds: [
        for (final id in data['videoIds'] as List? ?? const [])
          if (id is String) id,
      ],
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// "Private · 3 videos" / "Public · 1 video" / "No videos".
String playlistSubtitle({required bool isPrivate, required int count}) {
  final videos = switch (count) {
    0 => 'No videos',
    1 => '1 video',
    _ => '$count videos',
  };
  return '${isPrivate ? 'Private' : 'Public'} · $videos';
}

/// [items] with the item at [oldIndex] moved so it ends up at [newIndex]
/// (the indexes ReorderableListView.onReorderItem reports).
List<T> moveItem<T>(List<T> items, int oldIndex, int newIndex) {
  final result = [...items];
  if (oldIndex < 0 || oldIndex >= result.length) return result;
  final item = result.removeAt(oldIndex);
  result.insert(newIndex.clamp(0, result.length), item);
  return result;
}

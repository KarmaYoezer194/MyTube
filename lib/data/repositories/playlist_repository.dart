import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/channel.dart';
import '../models/playlist.dart';
import 'user_repository.dart';
import 'video_repository.dart';

/// My playlists and other channels' public playlists, in `playlists/`.
/// (Liked videos and Watch later are NOT stored here: they come from
/// `users/{uid}/reactions` and `users/{uid}/watchLater`.)
class PlaylistRepository {
  PlaylistRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  /// You can have up to this many playlists listed.
  static const int maxPlaylists = 50;

  CollectionReference<Map<String, dynamic>> get _playlists =>
      _db.collection('playlists');

  /// My playlists, most recently changed first (live).
  Stream<List<Playlist>> watchMyPlaylists() {
    return _playlists
        .where('ownerUid', isEqualTo: _uid)
        .orderBy('updatedAt', descending: true)
        .limit(maxPlaylists)
        .snapshots()
        .map((s) => [for (final doc in s.docs) Playlist.fromFirestore(doc)]);
  }

  /// One playlist (live). null if it was deleted. Someone else's private
  /// playlist can't be read at all (the stream gives an error).
  Stream<Playlist?> watchPlaylist(String id) {
    return _playlists
        .doc(id)
        .snapshots()
        .map((doc) => doc.exists ? Playlist.fromFirestore(doc) : null);
  }

  /// A channel's public playlists (for its Playlists tab).
  Stream<List<Playlist>> watchChannelPlaylists(String channelId) {
    return _playlists
        .where('channelId', isEqualTo: channelId)
        .where('visibility', isEqualTo: 'public')
        .orderBy('updatedAt', descending: true)
        .limit(30)
        .snapshots()
        .map((s) => [for (final doc in s.docs) Playlist.fromFirestore(doc)]);
  }

  /// Makes a new playlist (optionally already holding [firstVideoId]) and
  /// returns its id.
  Future<String> create({
    required String title,
    required String visibility,
    String? firstVideoId,
  }) async {
    final doc = _playlists.doc();
    await doc.set({
      'ownerUid': _uid,
      'channelId': Channel.idForUser(_uid),
      'title': title.trim(),
      'visibility': visibility,
      'videoIds': [?firstVideoId],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Rename and/or change Public / Private.
  Future<void> updateDetails(
    String id, {
    required String title,
    required String visibility,
  }) {
    return _playlists.doc(id).update({
      'title': title.trim(),
      'visibility': visibility,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) => _playlists.doc(id).delete();

  /// Adds the video at the end, or takes it out.
  Future<void> setContains(
    String id,
    String videoId, {
    required bool contains,
  }) {
    return _playlists.doc(id).update({
      'videoIds': contains
          ? FieldValue.arrayUnion([videoId])
          : FieldValue.arrayRemove([videoId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Saves a new order (after dragging).
  Future<void> reorder(String id, List<String> videoIds) {
    return _playlists.doc(id).update({
      'videoIds': videoIds,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

final playlistRepositoryProvider = Provider<PlaylistRepository>(
  (ref) => PlaylistRepository(
    ref.watch(firestoreProvider),
    ref.watch(currentUidProvider),
  ),
);

/// My playlists (empty for guests).
final myPlaylistsProvider = StreamProvider<List<Playlist>>((ref) {
  if (!ref.watch(isSignedInProvider)) return Stream.value(const []);
  return ref.watch(playlistRepositoryProvider).watchMyPlaylists();
});

/// One playlist, live.
final playlistProvider = StreamProvider.autoDispose.family<Playlist?, String>(
  (ref, id) => ref.watch(playlistRepositoryProvider).watchPlaylist(id),
);

/// A channel's public playlists.
final channelPlaylistsProvider = StreamProvider.autoDispose
    .family<List<Playlist>, String>(
      (ref, channelId) => ref
          .watch(playlistRepositoryProvider)
          .watchChannelPlaylists(channelId),
    );

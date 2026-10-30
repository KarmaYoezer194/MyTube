import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/avatar_colors.dart';
import '../models/app_user.dart';
import 'auth_repository.dart';
import 'video_repository.dart';

// So files that import this one can keep using currentUidProvider.
export 'auth_repository.dart' show currentUidProvider, isSignedInProvider;

/// Everything that belongs to ONE user, stored under `users/{uid}`:
///   (the document itself)  displayName, handle, avatarUrl, avatarColor,
///                          createdAt  (accounts only, not guests)
///   reactions/{videoId}   value: 1 (like) or -1 (dislike)
///   history/{videoId}     watchedAt, positionSeconds
///   watchLater/{videoId}  addedAt
///   subscribed/{channelId} addedAt
class UserRepository {
  UserRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  DocumentReference<Map<String, dynamic>> get _me =>
      _db.collection('users').doc(_uid);

  // ---------------- Profile ----------------

  /// My profile, or null if I don't have one (guests).
  Stream<AppUser?> watchProfile() {
    return _me.snapshots().map(
      (doc) => doc.exists ? AppUser.fromFirestore(doc) : null,
    );
  }

  /// My profile, read once (not live). null if I don't have one (guests).
  Future<AppUser?> getProfile() async {
    final doc = await _me.get();
    return doc.exists ? AppUser.fromFirestore(doc) : null;
  }

  /// Creates or updates `users/{uid}` when you sign up or sign in.
  ///
  /// Saves your name and its avatar color. Your @handle is made once and
  /// then kept, so it doesn't change every time you sign in. `merge: true`
  /// updates these fields without deleting anything else.
  Future<AppUser> saveProfile(String displayName) async {
    final name = displayName.trim();
    final existing = await getProfile();
    final handle = (existing?.handle.isNotEmpty ?? false)
        ? existing!.handle
        : makeHandle(name);
    final color = avatarColorFor(name).toARGB32();
    final avatarUrl = existing?.avatarUrl ?? '';

    await _me.set({
      'displayName': name,
      'handle': handle,
      'avatarUrl': avatarUrl,
      'avatarColor': color,
      if (existing == null) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return AppUser(
      uid: _uid,
      displayName: name,
      handle: handle,
      avatarUrl: avatarUrl,
      avatarColor: color,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );
  }

  /// "Karma Yoezer" -> "@karmayoezer4821". Only a-z and 0-9 are kept (names
  /// in other alphabets become "@user4821"); the random number makes it
  /// unlikely that two people get the same handle.
  static String makeHandle(String name) {
    var base = name.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    if (base.isEmpty) base = 'user';
    if (base.length > 15) base = base.substring(0, 15);
    final number = Random().nextInt(9000) + 1000;
    return '@$base$number';
  }

  // ---------------- Likes / dislikes ----------------

  /// 1 = liked, -1 = disliked, 0 = neither.
  Stream<int> watchReaction(String videoId) {
    return _me
        .collection('reactions')
        .doc(videoId)
        .snapshots()
        .map((doc) => (doc.data()?['value'] as num?)?.toInt() ?? 0);
  }

  /// [tapped] is 1 (like button) or -1 (dislike button). Tapping the one
  /// that's already on turns it off. The video's like counter is updated in
  /// the same batch, so the two can never get out of sync.
  Future<void> react({
    required String videoId,
    required int current,
    required int tapped,
  }) {
    final next = current == tapped ? 0 : tapped;
    final reaction = _me.collection('reactions').doc(videoId);
    final batch = _db.batch();

    if (next == 0) {
      batch.delete(reaction);
    } else {
      batch.set(reaction, {
        'value': next,
        'reactedAt': FieldValue.serverTimestamp(),
      });
    }

    // +1 if it becomes a like, -1 if a like is taken away.
    final likesChange = (next == 1 ? 1 : 0) - (current == 1 ? 1 : 0);
    if (likesChange != 0) {
      batch.update(_db.collection('videos').doc(videoId), {
        'likes': FieldValue.increment(likesChange),
      });
    }
    return batch.commit();
  }

  // ---------------- Watch later ----------------

  Stream<bool> watchIsInWatchLater(String videoId) {
    return _me
        .collection('watchLater')
        .doc(videoId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<void> setWatchLater(String videoId, {required bool saved}) {
    final doc = _me.collection('watchLater').doc(videoId);
    return saved
        ? doc.set({'addedAt': FieldValue.serverTimestamp()})
        : doc.delete();
  }

  // ---------------- Subscriptions ----------------

  Stream<bool> watchIsSubscribed(String channelId) {
    return _me
        .collection('subscribed')
        .doc(channelId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// Subscribe / unsubscribe. My record and the channel's subscriber
  /// counter (+1 / -1) change together in one batch; the rules check both.
  /// (Older channels without a channel document have no counter.)
  Future<void> setSubscribed(
    String channelId, {
    required bool subscribed,
  }) async {
    final doc = _me.collection('subscribed').doc(channelId);
    final channel = _db.collection('channels').doc(channelId);
    final snapshot = await channel.get();
    final count = (snapshot.data()?['subscriberCount'] as num?)?.toInt() ?? 0;
    final batch = _db.batch();
    if (subscribed) {
      batch.set(doc, {'addedAt': FieldValue.serverTimestamp()});
    } else {
      batch.delete(doc);
    }
    // A counter already at 0 (a subscription made before channels
    // existed) isn't lowered below 0.
    if (snapshot.exists && (subscribed || count > 0)) {
      batch.update(channel, {
        'subscriberCount': FieldValue.increment(subscribed ? 1 : -1),
      });
    }
    await batch.commit();
  }

  /// Ids of the channels I'm subscribed to, most recent first (up to
  /// [maxSubscriptions]).
  Stream<List<String>> watchSubscribedIds() {
    return _me
        .collection('subscribed')
        .orderBy('addedAt', descending: true)
        .limit(maxSubscriptions)
        .snapshots()
        .map((snapshot) => [for (final doc in snapshot.docs) doc.id]);
  }

  /// The Subscriptions tab shows up to this many channels.
  static const int maxSubscriptions = 50;

  // ---------------- Watch history ----------------

  /// Where you stopped last time (in seconds), or null if never watched.
  Future<int?> getHistoryPosition(String videoId) async {
    final doc = await _me.collection('history').doc(videoId).get();
    return (doc.data()?['positionSeconds'] as num?)?.toInt();
  }

  Future<void> saveHistory(String videoId, int positionSeconds) {
    return _me.collection('history').doc(videoId).set({
      'watchedAt': FieldValue.serverTimestamp(),
      'positionSeconds': positionSeconds,
    });
  }

  /// My watch history, most recent first (up to 100 videos).
  Stream<List<HistoryEntry>> watchHistory() {
    return _me
        .collection('history')
        .orderBy('watchedAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => [
            for (final doc in snapshot.docs)
              HistoryEntry(
                videoId: doc.id,
                positionSeconds:
                    (doc.data()['positionSeconds'] as num?)?.toInt() ?? 0,
                watchedAt: _time(doc.data()['watchedAt']),
              ),
          ],
        );
  }

  /// Removes one video from my history (and where I stopped in it).
  Future<void> removeFromHistory(String videoId) =>
      _me.collection('history').doc(videoId).delete();

  /// Deletes my whole watch history (resume positions too), 400 at a time
  /// (one batch can hold up to 500 writes).
  Future<void> clearHistory() async {
    while (true) {
      final snapshot = await _me.collection('history').limit(400).get();
      if (snapshot.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snapshot.docs.length < 400) return;
    }
  }

  // ---------------- Lists for the You tab ----------------

  /// Ids of videos I liked, most recent first.
  /// (Filtered and sorted in the app, so Firestore needs no extra index.)
  Stream<List<String>> watchLikedVideoIds() {
    return _me.collection('reactions').snapshots().map((snapshot) {
      final liked =
          snapshot.docs.where((doc) => doc.data()['value'] == 1).toList()..sort(
            (a, b) => _time(
              b.data()['reactedAt'],
            ).compareTo(_time(a.data()['reactedAt'])),
          );
      return [for (final doc in liked) doc.id];
    });
  }

  /// Ids of videos in Watch later, most recently added first.
  Stream<List<String>> watchWatchLaterIds() {
    return _me
        .collection('watchLater')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) => [for (final doc in snapshot.docs) doc.id]);
  }

  /// A Firestore time, or "now" while the server time isn't known yet.
  static DateTime _time(Object? value) =>
      value is Timestamp ? value.toDate() : DateTime.now();
}

/// One video in my watch history and where I stopped.
class HistoryEntry {
  const HistoryEntry({
    required this.videoId,
    required this.positionSeconds,
    required this.watchedAt,
  });

  final String videoId;
  final int positionSeconds;

  /// When I last watched it (groups the History page by day).
  final DateTime watchedAt;
}

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(
    ref.watch(firestoreProvider),
    ref.watch(currentUidProvider),
  ),
);

/// My profile (name + @handle), or null until I pick a name.
final myProfileProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(userRepositoryProvider).watchProfile(),
);

/// My reaction to a video: 1, -1 or 0.
final reactionProvider = StreamProvider.family<int, String>(
  (ref, videoId) => ref.watch(userRepositoryProvider).watchReaction(videoId),
);

/// Is this video in my Watch later list?
final isInWatchLaterProvider = StreamProvider.family<bool, String>(
  (ref, videoId) =>
      ref.watch(userRepositoryProvider).watchIsInWatchLater(videoId),
);

/// My watch history (video ids + positions), most recent first.
final historyEntriesProvider = StreamProvider<List<HistoryEntry>>(
  (ref) => ref.watch(userRepositoryProvider).watchHistory(),
);

/// Ids of the videos I liked.
final likedVideoIdsProvider = StreamProvider<List<String>>(
  (ref) => ref.watch(userRepositoryProvider).watchLikedVideoIds(),
);

/// Ids of the videos in my Watch later list.
final watchLaterIdsProvider = StreamProvider<List<String>>(
  (ref) => ref.watch(userRepositoryProvider).watchWatchLaterIds(),
);

/// Am I subscribed to this channel?
final isSubscribedProvider = StreamProvider.family<bool, String>(
  (ref, channelId) =>
      ref.watch(userRepositoryProvider).watchIsSubscribed(channelId),
);

/// Ids of the channels I'm subscribed to, most recent first.
final subscribedIdsProvider = StreamProvider<List<String>>(
  (ref) => ref.watch(userRepositoryProvider).watchSubscribedIds(),
);

/// Anyone's public profile (name, @handle, avatar), live. null if they
/// have none (guests).
final userProfileProvider = StreamProvider.autoDispose.family<AppUser?, String>(
  (ref, uid) => ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? AppUser.fromFirestore(doc) : null),
);

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../../core/utils/search_keywords.dart';
import '../models/channel.dart';
import '../models/video.dart';
import 'user_repository.dart';
import 'video_repository.dart';

/// Channels live at `channels/{channelId}`; handles are reserved at
/// `handles/{@handle}` (value: the owner's uid) so two accounts can't use
/// the same @handle.
class ChannelRepository {
  ChannelRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _channels =>
      _db.collection('channels');
  CollectionReference<Map<String, dynamic>> get _handles =>
      _db.collection('handles');
  CollectionReference<Map<String, dynamic>> get _videos =>
      _db.collection('videos');

  String get myChannelId => Channel.idForUser(_uid);

  // ---------------- Reading ----------------

  /// One channel, live. null if it has no document.
  Stream<Channel?> watchChannel(String channelId) {
    return _channels.doc(channelId).snapshots().map((doc) {
      if (!doc.exists) return null;
      final channel = Channel.fromFirestore(doc);
      if (!channel.hasKeywords) _fillKeywords(channel);
      return channel;
    });
  }

  /// Channels from before Phase 18 have no search keywords. The first
  /// person who sees one fills them in, once (the rules allow adding just
  /// this field while it is missing).
  void _fillKeywords(Channel channel) {
    if (!_keywordsFilled.add(channel.id)) return;
    _channels
        .doc(channel.id)
        .update({'keywords': channel.keywords})
        .catchError((Object e) => debugPrint('CHANNEL keywords: $e'));
  }

  static final _keywordsFilled = <String>{};

  /// Channels whose name or @handle has a word starting with [term]
  /// (search), most subscribers first.
  Query<Map<String, dynamic>> searchQuery(String term) => _channels
      .where('keywords', arrayContains: term)
      .orderBy('subscriberCount', descending: true);

  /// Several channels at once (one query per 30 ids). Missing ones are
  /// simply left out.
  Future<Map<String, Channel>> getChannels(List<String> ids) async {
    final result = <String, Channel>{};
    for (final part in chunked(ids, 30)) {
      final snapshot = await _channels
          .where(FieldPath.documentId, whereIn: part)
          .get();
      for (final doc in snapshot.docs) {
        result[doc.id] = Channel.fromFirestore(doc);
      }
    }
    return result;
  }

  /// How many PUBLIC videos and Shorts the channel has. A "count" query
  /// costs about one read, however many videos there are.
  Future<int> countPublicVideos(String channelId) async {
    final snapshot = await _videos
        .where('channelId', isEqualTo: channelId)
        .where('visibility', isEqualTo: 'public')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// Public videos (or Shorts) of these channels, newest first. Used by the
  /// channel page and the Subscriptions feed, one page at a time.
  /// Needs the composite index in firestore.indexes.json.
  Query<Map<String, dynamic>> publicVideosQuery({
    required List<String> channelIds,
    required bool shorts,
  }) {
    assert(channelIds.isNotEmpty && channelIds.length <= 30);
    final byChannel = channelIds.length == 1
        ? _videos.where('channelId', isEqualTo: channelIds.first)
        : _videos.where('channelId', whereIn: channelIds);
    return byChannel
        .where('visibility', isEqualTo: 'public')
        .where('isShort', isEqualTo: shorts)
        .orderBy('createdAt', descending: true);
  }

  // ---------------- Handles ----------------

  /// true if nobody else uses [handle] (normalized, with '@').
  Future<bool> isHandleAvailable(String handle) async {
    final reserved = await _handles.doc(handle).get();
    if (reserved.exists && reserved.data()?['uid'] != _uid) return false;
    // Older channels (and the sample ones) may not have reserved theirs.
    final sameHandle = await _channels
        .where('handle', isEqualTo: handle)
        .limit(2)
        .get();
    return sameHandle.docs.every((doc) => doc.id == myChannelId);
  }

  // ---------------- My channel ----------------

  /// Makes sure my channel document exists (accounts made before channels
  /// existed don't have one yet) and returns it.
  ///
  /// Also reserves my @handle. If someone else already has it (or it is an
  /// old-style handle), I get a new one.
  Future<Channel> ensureMyChannel(AppUser profile) async {
    final channelRef = _channels.doc(myChannelId);
    final existing = await channelRef.get();
    if (existing.exists) return Channel.fromFirestore(existing);

    var handle = profile.handle;
    final batch = _db.batch();
    var needsReservation = true;
    if (handleProblem(handle) != null) {
      handle = UserRepository.makeHandle(profile.displayName);
    } else {
      final reserved = await _handles.doc(handle).get();
      if (reserved.exists) {
        if (reserved.data()?['uid'] == _uid) {
          needsReservation = false;
        } else {
          handle = UserRepository.makeHandle(profile.displayName);
        }
      }
    }

    // The profile and the channel always share name, handle and color.
    batch.update(_db.collection('users').doc(_uid), {
      'handle': handle,
      'avatarColor': profile.avatarColor,
    });
    if (needsReservation) batch.set(_handles.doc(handle), {'uid': _uid});
    final channel = Channel(
      id: myChannelId,
      name: profile.displayName,
      handle: handle,
      description: '',
      bannerUrl: '',
      avatarUrl: profile.avatarUrl,
      avatarColor: profile.avatarColor,
      subscriberCount: 0,
      ownerUid: _uid,
      createdAt: DateTime.now(),
    );
    batch.set(channelRef, channel.toNewFirestore());
    await batch.commit();
    debugPrint('CHANNEL: created $myChannelId as $handle');
    return channel;
  }

  /// Saves "Edit channel" in one go (all or nothing):
  /// - the profile (users/{uid}) and channel get the same name, handle and
  ///   color;
  /// - a new handle is reserved and the old one released;
  /// - if the name or color changed, my videos show the new ones too.
  Future<void> saveMyChannel({
    required Channel current,
    required String name,
    required String handle,
    required String description,
    required String bannerUrl,
    required int avatarColor,
  }) async {
    final batch = _db.batch();
    batch.update(_db.collection('users').doc(_uid), {
      'displayName': name,
      'handle': handle,
      'avatarColor': avatarColor,
    });
    batch.update(_channels.doc(myChannelId), {
      'name': name,
      'handle': handle,
      'description': description,
      'bannerUrl': bannerUrl,
      'avatarColor': avatarColor,
      'keywords': channelKeywords(name: name, handle: handle),
    });

    if (handle != current.handle) {
      batch.set(_handles.doc(handle), {'uid': _uid});
      if (current.handle.isNotEmpty) {
        final old = await _handles.doc(current.handle).get();
        if (old.exists && old.data()?['uid'] == _uid) {
          batch.delete(old.reference);
        }
      }
    }

    if (name != current.name || avatarColor != current.avatarColor) {
      // A batch holds up to 500 writes; leave room for the 4 above.
      final mine = await _videos
          .where('uploaderUid', isEqualTo: _uid)
          .limit(450)
          .get();
      for (final doc in mine.docs) {
        final video = Video.fromFirestore(doc);
        batch.update(doc.reference, {
          'channelName': name,
          'channelAvatarColor': avatarColor,
          // The channel name is part of the video's search keywords.
          'keywords': videoKeywords(
            title: video.title,
            channelName: name,
            category: video.category,
          ),
        });
      }
    }
    await batch.commit();
  }
}

final channelRepositoryProvider = Provider<ChannelRepository>(
  (ref) => ChannelRepository(
    ref.watch(firestoreProvider),
    ref.watch(currentUidProvider),
  ),
);

/// One channel, live (null if it has no document yet).
final channelProvider = StreamProvider.family<Channel?, String>(
  (ref, channelId) =>
      ref.watch(channelRepositoryProvider).watchChannel(channelId),
);

/// Number of public videos + Shorts on a channel.
final channelVideoCountProvider = FutureProvider.family<int, String>(
  (ref, channelId) =>
      ref.watch(channelRepositoryProvider).countPublicVideos(channelId),
);

/// The channel to show for a video: its channel document, or (for older
/// uploads without one) a stand-in made from the video.
Channel channelOrFallback(Channel? channel, Video video) =>
    channel ?? Channel.fromVideo(video);

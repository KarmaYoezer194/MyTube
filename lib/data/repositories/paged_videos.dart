import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/video.dart';
import 'channel_repository.dart';

/// A list that loads [PagedVideosController.pageSize] videos at a time.
@immutable
class PagedVideos {
  const PagedVideos({
    this.items = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  final List<Video> items;

  /// A page is being loaded right now.
  final bool isLoading;

  /// false once the last page has been loaded.
  final bool hasMore;

  /// Why the last page failed (shown with a Retry button), or null.
  final Object? error;

  /// Nothing loaded yet, and still loading.
  bool get isFirstLoad => items.isEmpty && isLoading;

  /// Loaded everything and there is nothing.
  bool get isEmpty => items.isEmpty && !hasMore && error == null;
}

/// Loads a Firestore query one page at a time ("infinite scroll"), using
/// the last document as the bookmark for the next page. This keeps reads
/// low: you only pay for the videos you actually scroll to.
abstract class PagedVideosController extends Notifier<PagedVideos> {
  static const int pageSize = 12;

  DocumentSnapshot<Map<String, dynamic>>? _last;
  bool _busy = false;
  int _generation = 0;

  /// The query to page through (without limit). null = nothing to show.
  Query<Map<String, dynamic>>? buildQuery();

  @override
  PagedVideos build() {
    _last = null;
    _busy = false;
    final generation = ++_generation;
    // Load the first page right after the provider is set up.
    Future.microtask(() {
      if (generation == _generation) loadMore();
    });
    return const PagedVideos(isLoading: true);
  }

  /// Loads the next page (call it when the user nears the end of the list).
  /// Does nothing while a page is loading or after the last page.
  Future<void> loadMore() async {
    if (_busy || !state.hasMore) return;
    final query = buildQuery();
    if (query == null) {
      state = const PagedVideos(hasMore: false);
      return;
    }
    _busy = true;
    final generation = _generation;
    state = PagedVideos(items: state.items, isLoading: true);
    try {
      var page = query.limit(pageSize);
      if (_last != null) page = page.startAfterDocument(_last!);
      final snapshot = await page.get();
      if (!ref.mounted || generation != _generation) return;
      if (snapshot.docs.isNotEmpty) _last = snapshot.docs.last;
      state = PagedVideos(
        items: [...state.items, ...snapshot.docs.map(Video.fromFirestore)],
        hasMore: snapshot.docs.length == pageSize,
      );
    } catch (error) {
      // A missing index shows up here, with a link to create it.
      debugPrint('PAGED VIDEOS failed: $error');
      if (!ref.mounted || generation != _generation) return;
      state = PagedVideos(items: state.items, error: error);
    } finally {
      if (generation == _generation) _busy = false;
    }
  }
}

/// Which list of a channel: its long videos or its Shorts.
typedef ChannelVideosArg = ({String channelId, bool shorts});

/// A channel's public videos (or Shorts), newest first.
class ChannelVideosController extends PagedVideosController {
  ChannelVideosController(this.arg);

  final ChannelVideosArg arg;

  @override
  Query<Map<String, dynamic>>? buildQuery() => ref
      .read(channelRepositoryProvider)
      .publicVideosQuery(channelIds: [arg.channelId], shorts: arg.shorts);
}

final channelVideosProvider = NotifierProvider.autoDispose
    .family<ChannelVideosController, PagedVideos, ChannelVideosArg>(
      ChannelVideosController.new,
    );

/// The Subscriptions feed: newest public videos of up to 30 channels.
/// The argument is the channel ids joined with commas (a String, so the
/// same channels always give the same list).
class SubscriptionFeedController extends PagedVideosController {
  SubscriptionFeedController(this.channelIdsKey);

  final String channelIdsKey;

  @override
  Query<Map<String, dynamic>>? buildQuery() {
    if (channelIdsKey.isEmpty) return null;
    final ids = channelIdsKey.split(',').take(30).toList();
    return ref
        .read(channelRepositoryProvider)
        .publicVideosQuery(channelIds: ids, shorts: false);
  }
}

final subscriptionFeedProvider = NotifierProvider.autoDispose
    .family<SubscriptionFeedController, PagedVideos, String>(
      SubscriptionFeedController.new,
    );

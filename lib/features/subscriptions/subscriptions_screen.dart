import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/category_chip.dart';
import '../../core/widgets/channel_avatar.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/mytube_logo.dart';
import '../../core/widgets/paged_footer.dart';
import '../../data/models/channel.dart';
import '../../data/models/video.dart';
import '../../data/repositories/channel_repository.dart';
import '../../data/repositories/paged_videos.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/video_repository.dart';
import '../auth/sign_in_screen.dart';
import '../channel/channel_navigation.dart';
import '../home/widgets/video_card.dart';

/// The channels behind a list of ids (joined with commas), read once.
/// Channels without a document (older uploads) are made from one of their
/// videos, so every subscription still has a name and avatar.
final subscribedChannelsProvider = FutureProvider.autoDispose
    .family<Map<String, Channel>, String>((ref, idsKey) async {
      if (idsKey.isEmpty) return const {};
      final ids = idsKey.split(',');
      final found = await ref.read(channelRepositoryProvider).getChannels(ids);
      final videos = ref.read(allVideosProvider).value ?? const <Video>[];
      for (final id in ids) {
        if (found.containsKey(id)) continue;
        for (final video in videos) {
          if (video.channelId == id) {
            found[id] = Channel.fromVideo(video);
            break;
          }
        }
      }
      return found;
    });

/// Subscriptions tab:
/// - guests: "Don't miss new videos" + Sign in;
/// - no subscriptions: a friendly empty state;
/// - otherwise: a row of channel avatars, an "All" chip, and the newest
///   videos of those channels (loaded page by page). Tapping an avatar
///   shows only that channel's videos.
class SubscriptionsScreen extends ConsumerStatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  ConsumerState<SubscriptionsScreen> createState() =>
      _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> {
  /// The channel picked in the avatar row; null = All.
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: const MyTubeLogo(),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () => context.go('/home/search'),
            icon: const Icon(Symbols.search),
          ),
        ],
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (!ref.watch(isSignedInProvider)) {
      return EmptyState(
        icon: Symbols.subscriptions,
        title: "Don't miss new videos",
        message: 'Sign in to see updates from your favorite MyTube channels.',
        actionLabel: 'Sign in',
        onAction: () => openSignIn(context),
      );
    }

    final idsAsync = ref.watch(subscribedIdsProvider);
    if (idsAsync.hasError && !idsAsync.hasValue) {
      return EmptyState(
        icon: Symbols.error,
        title: "Couldn't load your subscriptions",
        message: 'Check your connection and try again.',
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(subscribedIdsProvider),
      );
    }
    final ids = idsAsync.value;
    if (ids == null) return const _FeedSkeleton();
    if (ids.isEmpty) {
      return EmptyState(
        icon: Symbols.subscriptions,
        title: 'No subscriptions yet',
        message:
            'Subscribe to channels you like, and their newest videos will '
            'show up here.',
        actionLabel: 'Explore videos',
        onAction: () => context.go('/home'),
      );
    }

    // A channel you unsubscribed from elsewhere can't stay selected.
    final selected = ids.contains(_selected) ? _selected : null;
    final channels =
        ref.watch(subscribedChannelsProvider(ids.join(','))).value ??
        const <String, Channel>{};
    // The feed covers your 30 most recent subscriptions (Firestore's
    // limit for one query).
    final feedKey = selected ?? ids.take(30).join(',');
    final feed = ref.watch(subscriptionFeedProvider(feedKey));
    final feedController = ref.read(subscriptionFeedProvider(feedKey).notifier);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(subscriptionFeedProvider(feedKey));
        ref.invalidate(subscribedChannelsProvider(ids.join(',')));
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => loadMoreWhenNearEnd(n, feedController.loadMore),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ---- Channel avatars ----
            SliverToBoxAdapter(
              child: SizedBox(
                height: 96,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: ids.length,
                  itemBuilder: (context, index) {
                    final id = ids[index];
                    return _ChannelBubble(
                      key: ValueKey(id),
                      channel: channels[id],
                      selected: id == selected,
                      dimmed: selected != null && id != selected,
                      onTap: () => setState(
                        () => _selected = id == selected ? null : id,
                      ),
                    );
                  },
                ),
              ),
            ),

            // ---- Chips: All, and "View channel" for a picked channel ----
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    CategoryChip(
                      label: 'All',
                      selected: selected == null,
                      onTap: () => setState(() => _selected = null),
                    ),
                    if (selected != null) ...[
                      const SizedBox(width: 8),
                      CategoryChip(
                        label: 'View channel',
                        icon: Symbols.account_box,
                        selected: false,
                        onTap: () => openChannel(context, ref, selected),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ---- Feed ----
            if (feed.isFirstLoad)
              const SliverToBoxAdapter(child: _FeedSkeleton(shrinkWrap: true))
            else if (feed.items.isEmpty && feed.error != null)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: Symbols.error,
                  title: "Couldn't load new videos",
                  message: 'Check your connection and try again.',
                  actionLabel: 'Retry',
                  onAction: () =>
                      ref.invalidate(subscriptionFeedProvider(feedKey)),
                ),
              )
            else if (feed.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: Symbols.video_library,
                  title: 'No videos yet',
                  message: selected == null
                      ? "Your subscriptions haven't posted any videos yet."
                      : "This channel hasn't posted any videos yet.",
                ),
              )
            else ...[
              SliverList.builder(
                itemCount: feed.items.length,
                itemBuilder: (context, index) => VideoCard(
                  key: ValueKey(feed.items[index].id),
                  video: feed.items[index],
                ),
              ),
              SliverToBoxAdapter(
                child: PagedFooter(
                  page: feed,
                  onRetry: feedController.loadMore,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One channel in the avatar row: avatar + short name. The picked one is
/// underlined; the others fade a little while one is picked.
class _ChannelBubble extends StatelessWidget {
  const _ChannelBubble({
    super.key,
    required this.channel,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final Channel? channel;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = channel?.name ?? '';
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: dimmed ? 0.45 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChannelAvatar(
                name: name,
                imageUrl: channel?.avatarUrl ?? '',
                color: channel?.avatarColorValue,
                size: 52,
              ),
              const SizedBox(height: 6),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: colors.textPrimary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(top: 3),
                height: 2,
                width: selected ? 24 : 0,
                color: colors.textPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton({this.shrinkWrap = false});

  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      children: const [VideoCardSkeleton(), VideoCardSkeleton()],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/mytube_logo.dart';
import '../../core/widgets/paged_footer.dart';
import '../../data/models/video.dart';
import '../../data/repositories/video_repository.dart';
import '../notifications/notifications_providers.dart';
import 'home_providers.dart';
import 'widgets/home_chips_bar.dart';
import 'widgets/recommended_shelf.dart';
import 'widgets/shorts_shelf.dart';
import 'widgets/video_card.dart';

/// Home tab: top bar + chips (hide when you scroll down, snap back when you
/// scroll up), "Recommended for you", the video feed (loaded page by page
/// as you scroll), a Shorts shelf after the 3rd video, and pull to refresh.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// The Shorts shelf goes after this many videos.
  static const int _shelfPosition = 3;

  void _notInDemo(BuildContext context, String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$what is not available in this demo')),
      );
  }

  Future<void> _refresh(WidgetRef ref, String chip) async {
    // Start the feed again from the newest video.
    ref.invalidate(homeFeedProvider(chip));
    ref.invalidate(allVideosProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chip = ref.watch(selectedCategoryProvider);
    final page = ref.watch(homeFeedProvider(chip));
    final controller = ref.read(homeFeedProvider(chip).notifier);
    final taste = ref.watch(tasteProfileProvider);
    final videos = [
      for (final video in page.items)
        if (!taste.hides(video)) video,
    ];

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref, chip),
        // Show the spinner below the top bar + chips, not behind them.
        edgeOffset: kToolbarHeight + HomeChipsBar.height,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) => loadMoreWhenNearEnd(n, controller.loadMore),
          child: CustomScrollView(
            // Lets you pull to refresh even when the list is short.
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                floating: true,
                snap: true,
                titleSpacing: 12,
                title: const MyTubeLogo(),
                actions: [
                  IconButton(
                    tooltip: 'Cast',
                    icon: const Icon(Symbols.cast),
                    onPressed: () => _notInDemo(context, 'Casting'),
                  ),
                  const _NotificationsBell(),
                  IconButton(
                    tooltip: 'Search',
                    icon: const Icon(Symbols.search),
                    onPressed: () => context.push('/home/search'),
                  ),
                ],
                bottom: const HomeChipsBar(),
              ),
              if (page.isFirstLoad)
                SliverList.builder(
                  itemCount: 3,
                  itemBuilder: (context, index) => const VideoCardSkeleton(),
                )
              else if (page.items.isEmpty && page.error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Symbols.cloud_off,
                    title: "Couldn't load videos",
                    message: 'Check your internet connection and try again.',
                    actionLabel: 'Retry',
                    onAction: () => ref.invalidate(homeFeedProvider(chip)),
                  ),
                )
              else if (videos.isEmpty && !page.hasMore)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _emptyFeed(ref, chip),
                )
              else ...[
                SliverList.list(children: _feed(ref, chip, videos)),
                SliverToBoxAdapter(
                  child: PagedFooter(page: page, onRetry: controller.loadMore),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyFeed(WidgetRef ref, String chip) {
    final isAll = chip == allCategory;
    return EmptyState(
      icon: Symbols.video_library,
      title: isAll ? 'No videos yet' : 'No videos in "$chip"',
      message: isAll
          ? 'Upload the first one with the + button.'
          : 'Try another category.',
      actionLabel: isAll ? null : 'Show all videos',
      onAction: isAll
          ? null
          : () =>
                ref.read(selectedCategoryProvider.notifier).select(allCategory),
    );
  }

  List<Widget> _feed(WidgetRef ref, String chip, List<Video> videos) {
    // The shelves only show on the "All" chip, like on YouTube.
    final isAll = chip == allCategory;
    final recommended = isAll
        ? ref.watch(recommendedProvider)
        : const <Video>[];
    final shorts = isAll ? ref.watch(homeShortsProvider) : const <Video>[];
    final shelfIndex = videos.length < _shelfPosition
        ? videos.length
        : _shelfPosition;

    return [
      if (recommended.isNotEmpty) RecommendedShelf(videos: recommended),
      for (var i = 0; i <= videos.length; i++) ...[
        if (shorts.isNotEmpty && i == shelfIndex) ShortsShelf(shorts: shorts),
        if (i < videos.length)
          VideoCard(key: ValueKey(videos[i].id), video: videos[i]),
      ],
    ];
  }
}

/// 🔔 with a red badge showing how many notifications are new.
class _NotificationsBell extends ConsumerWidget {
  const _NotificationsBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsCountProvider);

    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => context.push('/home/notifications'),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Symbols.notifications),
          if (unread > 0)
            Positioned(
              top: -4,
              right: -6,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16),
                height: 16,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: AppColors.brandRed,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

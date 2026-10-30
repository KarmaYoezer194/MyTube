import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/utils/format_views.dart';
import '../../core/widgets/channel_avatar.dart';
import '../../core/widgets/compact_video_row.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/network_thumbnail.dart';
import '../../core/widgets/paged_footer.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/subscribe_button.dart';
import '../../data/models/channel.dart';
import '../../data/models/video.dart';
import '../../data/repositories/channel_repository.dart';
import '../../data/repositories/paged_videos.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/video_repository.dart';
import '../home/widgets/shorts_shelf.dart';
import '../home/widgets/video_card.dart';
import 'edit_channel_screen.dart';

/// The 5 tabs of a channel page.
enum ChannelTab { home, videos, shorts, playlists, about }

extension on ChannelTab {
  String get label => switch (this) {
    ChannelTab.home => 'Home',
    ChannelTab.videos => 'Videos',
    ChannelTab.shorts => 'Shorts',
    ChannelTab.playlists => 'Playlists',
    ChannelTab.about => 'About',
  };
}

/// A channel page: banner, avatar, name, @handle, subscribers, video count,
/// Subscribe (or "Edit channel" on your own), and the tabs
/// Home / Videos / Shorts / Playlists / About.
///
/// Videos and Shorts load 12 at a time while you scroll.
class ChannelScreen extends ConsumerStatefulWidget {
  const ChannelScreen({super.key, required this.channelId});

  final String channelId;

  @override
  ConsumerState<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends ConsumerState<ChannelScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: ChannelTab.values.length,
    vsync: this,
  );
  final _scroll = ScrollController();
  final _headerKey = GlobalKey();
  bool _creatingMyChannel = false;

  ChannelTab get _tab => ChannelTab.values[_tabs.index];

  ChannelVideosArg get _videosArg =>
      (channelId: widget.channelId, shorts: false);
  ChannelVideosArg get _shortsArg =>
      (channelId: widget.channelId, shorts: true);

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    setState(() {});
    // Keep the tab bar at the top when switching tabs on a scrolled page.
    final header = _headerKey.currentContext?.size?.height;
    if (header != null && _scroll.hasClients && _scroll.offset > header) {
      _scroll.jumpTo(header);
    }
  }

  void _openTab(ChannelTab tab) => _tabs.animateTo(tab.index);

  /// Load the next page of the tab you're looking at.
  void _loadMore() {
    switch (_tab) {
      case ChannelTab.videos:
        ref.read(channelVideosProvider(_videosArg).notifier).loadMore();
      case ChannelTab.shorts:
        ref.read(channelVideosProvider(_shortsArg).notifier).loadMore();
      case ChannelTab.home || ChannelTab.playlists || ChannelTab.about:
        break;
    }
  }

  /// My own channel without a document yet (accounts from before
  /// channels existed): create it now.
  void _createMyChannelOnce() {
    if (_creatingMyChannel) return;
    final profile = ref.read(myProfileProvider).value;
    if (profile == null) return;
    _creatingMyChannel = true;
    ref.read(channelRepositoryProvider).ensureMyChannel(profile).catchError((
      Object error,
    ) {
      debugPrint('CHANNEL: could not create your channel: $error');
      return Channel.fromMap(widget.channelId, const {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final channelAsync = ref.watch(channelProvider(widget.channelId));
    // Keep both lists loaded while the page is open, so switching tabs
    // doesn't load them again.
    ref.watch(channelVideosProvider(_videosArg));
    ref.watch(channelVideosProvider(_shortsArg));
    final isMine =
        ref.watch(isSignedInProvider) &&
        widget.channelId == Channel.idForUser(ref.watch(currentUidProvider));

    // "Settled" = Firestore answered: with data, or with an error (e.g.
    // permission denied before the new rules are deployed). Riverpod keeps
    // retrying failed reads, so an error must not count as "still loading".
    final channelSettled = channelAsync.hasValue || channelAsync.hasError;
    if (channelAsync.hasError) {
      debugPrint('CHANNEL ${widget.channelId}: ${channelAsync.error}');
    }

    // Older uploads have no channel document: build one from a video.
    Channel? channel = channelAsync.value;
    if (channel == null && channelSettled) {
      if (isMine && channelAsync.hasValue) {
        ref.watch(myProfileProvider);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _createMyChannelOnce(),
        );
      }
      final videos = ref.watch(allVideosProvider).value ?? const <Video>[];
      for (final video in videos) {
        if (video.channelId == widget.channelId) {
          channel = Channel.fromVideo(video);
          break;
        }
      }
    }
    // No channel and no videos, but an account (e.g. someone who only
    // comments, or you): show their public profile as the channel.
    var profileSettled = true;
    if (channel == null &&
        channelSettled &&
        widget.channelId.startsWith('user-')) {
      final uid = widget.channelId.substring('user-'.length);
      final profile = ref.watch(userProfileProvider(uid));
      profileSettled = profile.hasValue || profile.hasError;
      final user = profile.value;
      if (user != null) channel = Channel.fromProfile(user);
    }

    final loading = channel == null && (!channelSettled || !profileSettled);
    final failed = channel == null && !loading && channelAsync.hasError;
    final missing = channel == null && !loading && !failed;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          channel?.name ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () => context.go('/home/search'),
            icon: const Icon(Symbols.search),
          ),
        ],
      ),
      body: failed
          ? EmptyState(
              icon: Symbols.error,
              title: "Couldn't load this channel",
              message:
                  'Check your connection. If it keeps happening, the '
                  'database rules may need to be deployed.',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(channelProvider(widget.channelId)),
            )
          : missing
          ? EmptyState(
              icon: Symbols.person_off,
              title: "This channel doesn't exist",
              message: 'It may have been removed.',
              actionLabel: 'Go home',
              onAction: () => context.go('/home'),
            )
          : NotificationListener<ScrollNotification>(
              onNotification: (n) => loadMoreWhenNearEnd(n, _loadMore),
              child: CustomScrollView(
                controller: _scroll,
                slivers: [
                  SliverToBoxAdapter(
                    child: KeyedSubtree(
                      key: _headerKey,
                      child: loading
                          ? const _HeaderSkeleton()
                          : _ChannelHeader(
                              channel: channel!,
                              isMine: isMine,
                              onMore: () => _openTab(ChannelTab.about),
                            ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabBarDelegate(
                      TabBar(
                        controller: _tabs,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        tabs: [
                          for (final tab in ChannelTab.values)
                            Tab(text: tab.label),
                        ],
                      ),
                      background: Theme.of(context).scaffoldBackgroundColor,
                      divider: context.colors.divider,
                    ),
                  ),
                  if (!loading)
                    ...switch (_tab) {
                      ChannelTab.home => _homeTab(),
                      ChannelTab.videos => _videosTab(),
                      ChannelTab.shorts => _shortsTab(),
                      ChannelTab.playlists => _playlistsTab(),
                      ChannelTab.about => _aboutTab(channel!),
                    },
                ],
              ),
            ),
    );
  }

  // ---------------- Tabs ----------------

  /// Newest video big, the next few as rows, then a Shorts shelf.
  List<Widget> _homeTab() {
    final videos = ref.watch(channelVideosProvider(_videosArg));
    final shorts = ref.watch(channelVideosProvider(_shortsArg));
    if (videos.isFirstLoad || shorts.isFirstLoad) {
      return [const SliverToBoxAdapter(child: _ListSkeleton())];
    }
    if (videos.items.isEmpty && shorts.items.isEmpty) {
      if (videos.error != null || shorts.error != null) {
        return [
          _errorSliver(() {
            ref.invalidate(channelVideosProvider(_videosArg));
            ref.invalidate(channelVideosProvider(_shortsArg));
          }),
        ];
      }
      return [_emptySliver("This channel doesn't have any content")];
    }
    final first = videos.items.firstOrNull;
    final more = videos.items.skip(1).take(4).toList();
    return [
      if (first != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: VideoCard(video: first),
          ),
        ),
      if (more.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: _SectionTitle(
            title: 'Videos',
            onViewAll: () => _openTab(ChannelTab.videos),
          ),
        ),
        SliverList.list(
          children: [
            for (final video in more)
              CompactVideoRow(key: ValueKey(video.id), video: video),
          ],
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
      if (shorts.items.isNotEmpty)
        SliverToBoxAdapter(child: ShortsShelf(shorts: shorts.items)),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];
  }

  List<Widget> _videosTab() {
    final page = ref.watch(channelVideosProvider(_videosArg));
    final controller = ref.read(channelVideosProvider(_videosArg).notifier);
    if (page.isFirstLoad) {
      return [const SliverToBoxAdapter(child: _ListSkeleton())];
    }
    if (page.items.isEmpty && page.error != null) {
      return [
        _errorSliver(() => ref.invalidate(channelVideosProvider(_videosArg))),
      ];
    }
    if (page.isEmpty) return [_emptySliver('No videos yet')];
    return [
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
      SliverList.builder(
        itemCount: page.items.length,
        itemBuilder: (context, index) => CompactVideoRow(
          key: ValueKey(page.items[index].id),
          video: page.items[index],
        ),
      ),
      SliverToBoxAdapter(
        child: PagedFooter(page: page, onRetry: controller.loadMore),
      ),
    ];
  }

  List<Widget> _shortsTab() {
    final page = ref.watch(channelVideosProvider(_shortsArg));
    final controller = ref.read(channelVideosProvider(_shortsArg).notifier);
    if (page.isFirstLoad) {
      return [const SliverToBoxAdapter(child: _ListSkeleton())];
    }
    if (page.items.isEmpty && page.error != null) {
      return [
        _errorSliver(() => ref.invalidate(channelVideosProvider(_shortsArg))),
      ];
    }
    if (page.isEmpty) return [_emptySliver('No Shorts yet')];
    return [
      SliverPadding(
        padding: const EdgeInsets.all(2),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: 9 / 16,
          ),
          itemCount: page.items.length,
          itemBuilder: (context, index) => _ShortTile(
            key: ValueKey(page.items[index].id),
            video: page.items[index],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: PagedFooter(page: page, onRetry: controller.loadMore),
      ),
    ];
  }

  List<Widget> _playlistsTab() => [
    _emptySliver(
      'No playlists',
      message: "This channel doesn't have any public playlists.",
    ),
  ];

  List<Widget> _aboutTab(Channel channel) {
    final colors = context.colors;
    final count = ref.watch(channelVideoCountProvider(channel.id)).value;
    final text = TextStyle(color: colors.textPrimary, fontSize: 14);
    Widget row(IconData icon, String label) => ListTile(
      dense: true,
      leading: Icon(icon, color: colors.textPrimary),
      title: Text(label, style: text),
    );

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Description',
                style: AppTextStyles.sectionHeader.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                channel.description.isEmpty
                    ? 'No description yet.'
                    : channel.description,
                style: AppTextStyles.body.copyWith(
                  color: channel.description.isEmpty
                      ? colors.textSecondary
                      : colors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'More info',
                style: AppTextStyles.sectionHeader.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
      SliverList.list(
        children: [
          if (channel.handle.isNotEmpty)
            row(Symbols.alternate_email, channel.handle),
          row(Symbols.person, formatSubscribers(channel.subscriberCount)),
          if (count != null)
            row(Symbols.play_circle, count == 1 ? '1 video' : '$count videos'),
          row(
            Symbols.info,
            'Joined ${DateFormat.yMMMd().format(channel.createdAt)}',
          ),
        ],
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];
  }

  Widget _emptySliver(String title, {String? message}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: EmptyState(
          icon: Symbols.video_library,
          title: title,
          message: message,
        ),
      ),
    );
  }

  Widget _errorSliver(VoidCallback onRetry) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: EmptyState(
          icon: Symbols.error,
          title: "Couldn't load this channel's videos",
          message: 'Check your connection and try again.',
          actionLabel: 'Retry',
          onAction: onRetry,
        ),
      ),
    );
  }
}

// ---------------- Header ----------------

class _ChannelHeader extends ConsumerWidget {
  const _ChannelHeader({
    required this.channel,
    required this.isMine,
    required this.onMore,
  });

  final Channel channel;
  final bool isMine;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final count = ref.watch(channelVideoCountProvider(channel.id)).value;
    final meta = AppTextStyles.meta.copyWith(
      color: colors.textSecondary,
      fontSize: 13,
    );
    final stats = [
      formatSubscribers(
        channel.subscriberCount < 0 ? 0 : channel.subscriberCount,
      ),
      if (count != null) count == 1 ? '1 video' : '$count videos',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (channel.bannerUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 4,
                child: NetworkThumbnail(url: channel.bannerUrl),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              ChannelAvatar(
                name: channel.name,
                imageUrl: channel.avatarUrl,
                color: channel.avatarColorValue,
                size: 72,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.sectionHeader.copyWith(
                        fontSize: 24,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (channel.handle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        channel.handle,
                        style: meta.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(stats, style: meta),
                  ],
                ),
              ),
            ],
          ),
          if (channel.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: onMore,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      channel.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: meta,
                    ),
                  ),
                  Icon(
                    Symbols.chevron_right,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (isMine)
            SizedBox(
              width: double.infinity,
              height: 36,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.surface,
                  foregroundColor: colors.textPrimary,
                  shape: const StadiumBorder(),
                ),
                onPressed: () => openEditChannel(context, channel),
                child: const Text('Edit channel'),
              ),
            )
          else
            SubscribeButton(
              channelId: channel.id,
              channelName: channel.name,
              fullWidth: true,
            ),
        ],
      ),
    );
  }
}

class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Skeleton(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          children: [
            AspectRatio(aspectRatio: 4, child: SkeletonBox(radius: 12)),
            SizedBox(height: 16),
            Row(
              children: [
                SkeletonBox(width: 72, height: 72, circle: true),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 180, height: 22),
                      SizedBox(height: 8),
                      SkeletonBox(width: 140, height: 12),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            SkeletonBox(width: double.infinity, height: 36, radius: 18),
          ],
        ),
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 8),
      child: Column(
        children: [
          CompactVideoRowSkeleton(),
          CompactVideoRowSkeleton(),
          CompactVideoRowSkeleton(),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.onViewAll});

  final String title;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.sectionHeader.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
          IconButton(
            tooltip: 'All videos',
            onPressed: onViewAll,
            icon: const Icon(Symbols.chevron_right),
          ),
        ],
      ),
    );
  }
}

/// A Short in the channel's Shorts grid: tall thumbnail with the title and
/// views on top. Opens it in the Shorts tab.
class _ShortTile extends StatelessWidget {
  const _ShortTile({super.key, required this.video});

  final Video video;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/shorts?v=${video.id}'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          NetworkThumbnail(url: video.thumbnailUrl),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xAA000000)],
              ),
            ),
          ),
          Positioned(
            left: 6,
            right: 6,
            bottom: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  formatViews(video.views),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Keeps the tab bar pinned under the app bar while the header scrolls away.
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(
    this.tabBar, {
    required this.background,
    required this.divider,
  });

  final TabBar tabBar;
  final Color background;
  final Color divider;

  @override
  double get minExtent => tabBar.preferredSize.height + 1;
  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        border: Border(bottom: BorderSide(color: divider)),
      ),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) =>
      oldDelegate.tabBar != tabBar ||
      oldDelegate.background != background ||
      oldDelegate.divider != divider;
}

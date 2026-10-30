import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/utils/format_views.dart';
import '../../core/widgets/category_chip.dart';
import '../../core/widgets/compact_video_row.dart';
import '../../core/widgets/duration_badge.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/network_thumbnail.dart';
import '../../data/models/channel.dart';
import '../../data/models/video.dart';
import '../../data/repositories/channel_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/video_repository.dart';
import '../upload/create_sheet.dart';
import '../you/you_providers.dart';
import 'delete_video.dart';
import 'edit_video_screen.dart';
import 'studio_stats.dart';
import 'video_stats_screen.dart';
import 'widgets/stat_tile.dart';

/// My Studio: channel dashboard (subscribers, views, likes, comments,
/// uploads, top video) and all my uploads - including unlisted ones -
/// with Edit, Analytics and Delete.
///
/// Everything is worked out from data the app already has (the video list
/// and my channel), so the Studio costs no extra Firestore reads.
class StudioScreen extends ConsumerStatefulWidget {
  const StudioScreen({super.key});

  @override
  ConsumerState<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends ConsumerState<StudioScreen> {
  StudioFilter _filter = StudioFilter.all;
  StudioSort _sort = StudioSort.newest;

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myVideosProvider);
    final uid = ref.watch(currentUidProvider);
    final channel = ref.watch(channelProvider(Channel.idForUser(uid))).value;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/you'),
          icon: const Icon(Symbols.arrow_back),
        ),
        title: const Text('Studio'),
        actions: [
          IconButton(
            tooltip: 'Upload',
            onPressed: () => showCreateSheet(context, ref),
            icon: const Icon(Symbols.add_circle),
          ),
        ],
      ),
      body: mine.when(
        loading: () => ListView.builder(
          itemCount: 6,
          itemBuilder: (context, index) => const CompactVideoRowSkeleton(),
        ),
        error: (error, stackTrace) => EmptyState(
          icon: Symbols.cloud_off,
          title: "Couldn't load your videos",
          message: 'Check your internet connection and try again.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(allVideosProvider),
        ),
        data: (items) {
          final videos = [for (final item in items) item.video];
          if (videos.isEmpty) {
            return EmptyState(
              icon: Symbols.video_library,
              title: 'No videos yet',
              message:
                  'Upload a video or Short and its numbers will show up '
                  'here.',
              actionLabel: 'Upload a video',
              onAction: () => showCreateSheet(context, ref),
            );
          }
          final stats = channelStatsOf(videos);
          final list = studioList(videos, _filter, _sort);

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              // ---- Channel dashboard ----
              const StudioSectionTitle('Channel dashboard'),
              StatGrid(
                tiles: [
                  StatTile(
                    icon: Symbols.group,
                    value: channel == null
                        ? '-'
                        : formatCompactCount(channel.subscriberCount),
                    label: 'Subscribers',
                  ),
                  StatTile(
                    icon: Symbols.visibility,
                    value: formatCompactCount(stats.views),
                    label: 'Views',
                  ),
                  StatTile(
                    icon: Symbols.thumb_up,
                    value: formatCompactCount(stats.likes),
                    label: 'Likes',
                  ),
                  StatTile(
                    icon: Symbols.comment,
                    value: formatCompactCount(stats.comments),
                    label: 'Comments',
                  ),
                  StatTile(
                    icon: Symbols.smart_display,
                    value: '${stats.videoCount}',
                    label: 'Videos',
                  ),
                  StatTile(
                    icon: Symbols.movie,
                    value: '${stats.shortCount}',
                    label: 'Shorts',
                  ),
                ],
              ),
              if (stats.topVideo case final top?) ...[
                const StudioSectionTitle('Top upload'),
                _StudioVideoRow(video: top),
              ],

              // ---- Content ----
              StudioSectionTitle(
                'Content',
                trailing: PopupMenuButton<StudioSort>(
                  tooltip: 'Sort',
                  initialValue: _sort,
                  onSelected: (sort) => setState(() => _sort = sort),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: StudioSort.newest,
                      child: Text('Newest'),
                    ),
                    PopupMenuItem(
                      value: StudioSort.mostViewed,
                      child: Text('Most viewed'),
                    ),
                    PopupMenuItem(
                      value: StudioSort.mostLiked,
                      child: Text('Most liked'),
                    ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(switch (_sort) {
                          StudioSort.newest => 'Newest',
                          StudioSort.mostViewed => 'Most viewed',
                          StudioSort.mostLiked => 'Most liked',
                        }, style: TextStyle(color: context.colors.textPrimary)),
                        const SizedBox(width: 4),
                        Icon(Symbols.sort, color: context.colors.textPrimary),
                      ],
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    for (final filter in StudioFilter.values) ...[
                      CategoryChip(
                        label: switch (filter) {
                          StudioFilter.all => 'All',
                          StudioFilter.videos => 'Videos',
                          StudioFilter.shorts => 'Shorts',
                        },
                        selected: _filter == filter,
                        onTap: () => setState(() => _filter = filter),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _filter == StudioFilter.shorts
                        ? 'No Shorts yet.'
                        : 'No videos yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
                )
              else
                for (final video in list)
                  _StudioVideoRow(key: ValueKey(video.id), video: video),
            ],
          );
        },
      ),
    );
  }
}

/// One upload in the Studio: thumbnail, title, Public/Unlisted · date,
/// 👁 views · 👍 likes · 💬 comments, and a ⋮ menu.
/// Tap = its analytics.
class _StudioVideoRow extends ConsumerWidget {
  const _StudioVideoRow({super.key, required this.video});

  final Video video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final meta = AppTextStyles.meta.copyWith(color: colors.textSecondary);

    Widget stat(IconData icon, int value) => Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.textSecondary),
          const SizedBox(width: 3),
          Text(formatCompactCount(value), style: meta),
        ],
      ),
    );

    return InkWell(
      onTap: () => openVideoStats(context, video.id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 0, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 120,
                height: 68,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetworkThumbnail(url: video.thumbnailUrl),
                    if (video.durationSeconds > 0)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: DurationBadge(duration: video.duration),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.videoTitle.copyWith(
                      fontSize: 14,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        video.isUnlisted ? Symbols.link : Symbols.public,
                        size: 14,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${video.isUnlisted ? 'Unlisted' : 'Public'}'
                          '${video.isShort ? ' Short' : ''} · '
                          '${DateFormat.yMMMd().format(video.createdAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: meta,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      stat(Symbols.visibility, video.views),
                      stat(Symbols.thumb_up, video.likes),
                      stat(Symbols.comment, video.commentCount ?? 0),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'More actions',
              icon: const Icon(Symbols.more_vert, size: 20),
              onSelected: (choice) {
                switch (choice) {
                  case 'stats':
                    openVideoStats(context, video.id);
                  case 'edit':
                    openEditVideo(context, video);
                  case 'delete':
                    confirmAndDeleteVideo(context, ref, video);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'stats', child: Text('Analytics')),
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

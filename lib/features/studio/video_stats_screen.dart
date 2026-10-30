import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/utils/format_views.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/network_thumbnail.dart';
import '../../data/models/video.dart';
import '../../data/repositories/video_repository.dart';
import '../mini_player/player_panel_provider.dart';
import '../you/you_providers.dart';
import 'delete_video.dart';
import 'edit_video_screen.dart';
import 'studio_stats.dart';
import 'widgets/stat_tile.dart';

/// Opens one video's stats over everything.
Future<void> openVideoStats(BuildContext context, String videoId) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(builder: (_) => VideoStatsScreen(videoId: videoId)),
  );
}

/// Studio → one video: its numbers, how it compares to the rest of my
/// channel, and Watch / Edit / Delete.
class VideoStatsScreen extends ConsumerWidget {
  const VideoStatsScreen({super.key, required this.videoId});

  final String videoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoAsync = ref.watch(videoProvider(videoId));
    final video = videoAsync.value;
    final mine = [
      for (final item
          in ref.watch(myVideosProvider).value ?? const <ListedVideo>[])
        item.video,
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Symbols.arrow_back),
        ),
        title: const Text('Video analytics'),
        actions: [
          if (video != null) ...[
            IconButton(
              tooltip: 'Edit',
              onPressed: () => openEditVideo(context, video),
              icon: const Icon(Symbols.edit),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: () async {
                final navigator = Navigator.of(context);
                if (await confirmAndDeleteVideo(context, ref, video)) {
                  navigator.pop();
                }
              },
              icon: const Icon(Symbols.delete),
            ),
          ],
        ],
      ),
      body: video == null
          ? (videoAsync is AsyncLoading
                ? const Center(child: CircularProgressIndicator())
                : const EmptyState(
                    icon: Symbols.error,
                    title: 'Video not found',
                    message: 'It may have been deleted.',
                  ))
          : _Body(video: video, mine: mine),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.video, required this.mine});

  final Video video;

  /// All my uploads (for the comparisons).
  final List<Video> mine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final channel = channelStatsOf(mine);
    final now = DateTime.now();
    final meta = AppTextStyles.meta.copyWith(color: colors.textSecondary);
    final comments = video.commentCount ?? 0;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // ---- The video ----
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 140,
                  height: 79,
                  child: NetworkThumbnail(url: video.thumbnailUrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.videoTitle.copyWith(
                        fontSize: 15,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${video.isShort ? 'Short' : 'Video'} · '
                      '${video.isUnlisted ? 'Unlisted' : 'Public'}',
                      style: meta,
                    ),
                    Text(
                      'Uploaded ${DateFormat.yMMMd().format(video.createdAt)}',
                      style: meta,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: FilledButton.icon(
            onPressed: () {
              final router = GoRouter.of(context);
              // Close the Studio pages that cover the app, then play it.
              Navigator.of(context).popUntil((route) => route.isFirst);
              if (video.isShort) {
                router.go('/shorts?v=${video.id}');
              } else {
                ref.read(playerPanelProvider.notifier).open(video.id);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: colors.chipSelectedBackground,
              foregroundColor: colors.chipSelectedForeground,
            ),
            icon: const Icon(Symbols.play_arrow, fill: 1),
            label: const Text('Watch'),
          ),
        ),

        // ---- Numbers ----
        const StudioSectionTitle('Overview'),
        StatGrid(
          tiles: [
            StatTile(
              icon: Symbols.visibility,
              value: formatCompactCount(video.views),
              label: 'Views',
            ),
            StatTile(
              icon: Symbols.thumb_up,
              value: formatCompactCount(video.likes),
              label: 'Likes',
            ),
            StatTile(
              icon: Symbols.comment,
              value: formatCompactCount(comments),
              label: 'Comments',
            ),
            StatTile(
              icon: Symbols.favorite,
              value: formatPercent(likeRate(video)),
              label: 'Likes per view',
            ),
            StatTile(
              icon: Symbols.trending_up,
              value: viewsPerDay(video, now).toStringAsFixed(1),
              label: 'Views per day',
            ),
            StatTile(
              icon: Symbols.timer,
              value: video.durationSeconds > 0
                  ? _clock(video.durationSeconds)
                  : '-',
              label: 'Length',
            ),
          ],
        ),

        // ---- Compared to the channel ----
        if (mine.length > 1) ...[
          const StudioSectionTitle('Compared to your channel'),
          _CompareRow(
            icon: Symbols.leaderboard,
            text:
                '#${viewsRank(mine, video)} of ${mine.length} uploads by views',
          ),
          _CompareRow(
            icon: Symbols.visibility,
            text:
                "${formatPercent(shareOf(video.views, channel.views))} of "
                "your channel's views",
          ),
          _CompareRow(
            icon: Symbols.thumb_up,
            text:
                "${formatPercent(shareOf(video.likes, channel.likes))} of "
                "your channel's likes",
          ),
          _CompareRow(
            icon: Symbols.comment,
            text:
                "${formatPercent(shareOf(comments, channel.comments))} of "
                "your channel's comments",
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Text(
            'Numbers update live. Dislikes and watch time are not counted '
            'in this demo.',
            style: meta,
          ),
        ),
      ],
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: context.colors.textSecondary),
      title: Text(
        text,
        style: AppTextStyles.body.copyWith(color: context.colors.textPrimary),
      ),
    );
  }
}

/// 75 -> "1:15", 3725 -> "1:02:05".
String _clock(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

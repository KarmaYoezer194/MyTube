import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/format_views.dart';
import '../../../core/utils/time_ago.dart';
import '../../../core/widgets/channel_avatar.dart';
import '../../../core/widgets/duration_badge.dart';
import '../../../core/widgets/network_thumbnail.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/models/video.dart';
import '../../mini_player/player_panel_provider.dart';
import 'video_options_sheet.dart';

/// A video on the Home feed: full-width 16:9 thumbnail, then the channel
/// avatar, title, "Channel · 1.2M views · 3 days ago" and a ⋮ button.
class VideoCard extends ConsumerWidget {
  const VideoCard({super.key, required this.video});

  final Video video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return InkWell(
      onTap: () => ref.read(playerPanelProvider.notifier).open(video.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                NetworkThumbnail(url: video.thumbnailUrl),
                if (video.durationSeconds > 0)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: DurationBadge(duration: video.duration),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 0, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChannelAvatar(
                  name: video.channelName,
                  imageUrl: video.channelAvatarUrl,
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
                        style: AppTextStyles.videoTitle
                            .copyWith(color: colors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${video.channelName} · ${formatViews(video.views)}'
                        ' · ${timeAgo(video.createdAt)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.meta
                            .copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'More actions',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Symbols.more_vert, size: 20),
                  onPressed: () => showVideoOptionsSheet(context, ref, video),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The grey shimmering shape of a [VideoCard], shown while the feed loads.
class VideoCardSkeleton extends StatelessWidget {
  const VideoCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Skeleton(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(aspectRatio: 16 / 9, child: SkeletonBox(radius: 0)),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 36, height: 36, circle: true),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(height: 14, width: double.infinity),
                      SizedBox(height: 6),
                      SkeletonBox(height: 14, width: 200),
                      SizedBox(height: 8),
                      SkeletonBox(height: 12, width: 150),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

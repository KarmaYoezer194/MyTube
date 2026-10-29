import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/format_views.dart';
import '../../../core/utils/share_video.dart';
import '../../../core/utils/time_ago.dart';
import '../../../core/widgets/animated_toggle_icon.dart';
import '../../../core/widgets/channel_avatar.dart';
import '../../../core/widgets/subscribe_button.dart';
import '../../../data/models/video.dart';
import '../../../data/repositories/user_repository.dart';
import '../../comments/comments_preview_card.dart';
import 'description_sheet.dart';

/// Everything between the player and the "Up next" list: title + meta line,
/// channel row with Subscribe, the action pills and the comments card.
class WatchDetails extends ConsumerWidget {
  const WatchDetails({super.key, required this.video});

  final Video video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(userRepositoryProvider);

    void showMessage(String text) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    }

    void showSaveError(Object _) =>
        showMessage("Couldn't save. Check your internet connection.");

    // My like/dislike and Watch later state (live from Firestore).
    final reaction = ref.watch(reactionProvider(video.id)).value ?? 0;
    final saved = ref.watch(isInWatchLaterProvider(video.id)).value ?? false;

    void react(int tapped) {
      repository
          .react(videoId: video.id, current: reaction, tapped: tapped)
          .catchError(showSaveError);
    }

    void toggleWatchLater() {
      repository
          .setWatchLater(video.id, saved: !saved)
          .then((_) => showMessage(
              saved ? 'Removed from Watch later' : 'Saved to Watch later'))
          .catchError(showSaveError);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- Title + "views · time ...more" (tap = description) ----
        InkWell(
          onTap: () => showDescriptionSheet(context, video),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.watchTitle
                      .copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${formatViews(video.views)}  '
                            '${timeAgo(video.createdAt)}  ',
                      ),
                      TextSpan(
                        text: '...more',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  style: AppTextStyles.meta.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ),

        // ---- Channel row ----
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(
            children: [
              ChannelAvatar(
                name: video.channelName,
                imageUrl: video.channelAvatarUrl,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  video.channelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatCompactCount(video.subscriberCount),
                style: AppTextStyles.meta.copyWith(color: colors.textSecondary),
              ),
              const Spacer(),
              SubscribeButton(
                channelId: video.channelId,
                channelName: video.channelName,
              ),
            ],
          ),
        ),

        // ---- Action pills (scroll sideways) ----
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              _LikeDislikePill(
                likes: video.likes,
                reaction: reaction,
                onLike: () => react(1),
                onDislike: () => react(-1),
              ),
              const SizedBox(width: 8),
              _ActionPill(
                icon: Symbols.share,
                label: 'Share',
                onTap: () => shareVideo(messenger, video),
              ),
              const SizedBox(width: 8),
              _ActionPill(
                icon: Symbols.download,
                label: 'Download',
                onTap: () =>
                    showMessage('Downloads are not available in this demo'),
              ),
              const SizedBox(width: 8),
              _ActionPill(
                icon: Symbols.bookmark,
                label: saved ? 'Saved' : 'Save',
                active: saved,
                onTap: toggleWatchLater,
              ),
              const SizedBox(width: 8),
              _ActionPill(
                icon: Symbols.content_cut,
                label: 'Clip',
                onTap: () =>
                    showMessage('Clips are not available in this demo'),
              ),
            ],
          ),
        ),

        // ---- Comments card (tap = comments sheet) ----
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          child: CommentsPreviewCard(videoId: video.id),
        ),
      ],
    );
  }
}

/// One rounded grey pill with an icon and a label.
/// [active] fills the icon (e.g. Save -> Saved).
class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              AnimatedToggleIcon(
                icon: icon,
                active: active,
                color: colors.textPrimary,
              ),
              const SizedBox(width: 6),
              Text(label,
                  style: AppTextStyles.chip.copyWith(color: colors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Like and dislike joined in one pill: [👍 12K | 👎]
class _LikeDislikePill extends StatelessWidget {
  const _LikeDislikePill({
    required this.likes,
    required this.reaction,
    required this.onLike,
    required this.onDislike,
  });

  final int likes;

  /// 1 = liked, -1 = disliked, 0 = neither.
  final int reaction;
  final VoidCallback onLike;
  final VoidCallback onDislike;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          InkWell(
            onTap: onLike,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 12, 0),
              child: Row(
                children: [
                  AnimatedToggleIcon(
                    icon: Symbols.thumb_up,
                    active: reaction == 1,
                    color: colors.textPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formatCompactCount(likes),
                    style:
                        AppTextStyles.chip.copyWith(color: colors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 20, color: colors.divider),
          InkWell(
            onTap: onDislike,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
              child: AnimatedToggleIcon(
                icon: Symbols.thumb_down,
                active: reaction == -1,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

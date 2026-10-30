import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/format_views.dart';
import '../../../core/utils/time_ago.dart';
import '../../../core/widgets/channel_avatar.dart';
import '../../../data/models/comment.dart';

/// YouTube's blue for "3 replies" (a bit lighter in dark mode).
Color replyLinkColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF3EA6FF)
    : const Color(0xFF065FD4);

/// "@handle · 3 days ago (edited)".
String commentHeader(Comment comment, {DateTime? now}) =>
    '${comment.handle} · ${timeAgo(comment.createdAt, now: now)}'
    '${comment.edited ? ' (edited)' : ''}';

/// One comment or reply: avatar, "@handle · time", text, then
/// 👍 count, creator heart, Reply, and a ⋮ menu.
class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.comment,
    required this.liked,
    required this.onLike,
    required this.onReply,
    required this.onOpenChannel,
    required this.creatorName,
    this.byCreator = false,
    this.pinned = false,
    this.onHeart,
    this.onMore,
  });

  final Comment comment;
  final bool liked;
  final ValueChanged<bool> onLike;
  final VoidCallback onReply;

  /// Tapping the avatar opens the author's channel.
  final VoidCallback onOpenChannel;

  /// The video's channel name ("Pinned by …", the heart's tooltip).
  final String creatorName;

  /// The author is the video's uploader: their handle gets a grey pill.
  final bool byCreator;

  /// Shown at the top with "Pinned by …".
  final bool pinned;

  /// Only for the video's uploader: give / take back a heart.
  final VoidCallback? onHeart;

  /// The ⋮ menu (edit, delete, pin). null = no menu.
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final secondary = AppTextStyles.meta.copyWith(color: colors.textSecondary);
    final avatarSize = comment.isReply ? 24.0 : 28.0;

    final header = Text(commentHeader(comment), style: secondary);

    return Padding(
      padding: EdgeInsets.fromLTRB(comment.isReply ? 56 : 16, 10, 4, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onOpenChannel,
            child: ChannelAvatar(
              name: comment.displayName,
              imageUrl: comment.avatarUrl,
              size: avatarSize,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pinned)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          Symbols.push_pin,
                          size: 14,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Pinned by $creatorName',
                            overflow: TextOverflow.ellipsis,
                            style: secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (byCreator)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: header,
                  )
                else
                  header,
                const SizedBox(height: 2),
                Text(
                  comment.text,
                  style: AppTextStyles.body.copyWith(color: colors.textPrimary),
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: liked ? 'Unlike' : 'Like',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      onPressed: () => onLike(!liked),
                      icon: Icon(
                        Symbols.thumb_up,
                        size: 16,
                        fill: liked ? 1 : 0,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (comment.likes > 0)
                      Text(formatCompactCount(comment.likes), style: secondary),
                    const SizedBox(width: 4),
                    _HeartButton(
                      hearted: comment.hearted,
                      creatorName: creatorName,
                      onTap: onHeart,
                    ),
                    TextButton(
                      onPressed: onReply,
                      style: TextButton.styleFrom(
                        foregroundColor: colors.textPrimary,
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: const Text('Reply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onMore != null)
            IconButton(
              tooltip: 'More',
              visualDensity: VisualDensity.compact,
              onPressed: onMore,
              icon: Icon(
                Symbols.more_vert,
                size: 18,
                color: colors.textPrimary,
              ),
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }
}

/// The creator heart.
/// - The uploader sees a heart button they can tap ([onTap] not null).
/// - Everyone else only sees it once it was given: the creator's small
///   avatar with a red heart on it.
class _HeartButton extends StatelessWidget {
  const _HeartButton({
    required this.hearted,
    required this.creatorName,
    required this.onTap,
  });

  final bool hearted;
  final String creatorName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final badge = SizedBox(
      width: 22,
      height: 22,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ChannelAvatar(name: creatorName, size: 18),
          const Positioned(
            right: -2,
            bottom: -2,
            child: Icon(
              Symbols.favorite,
              fill: 1,
              size: 12,
              color: AppColors.brandRed,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      if (!hearted) return const SizedBox.shrink();
      return Tooltip(
        message: 'Hearted by $creatorName',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: badge,
        ),
      );
    }
    return IconButton(
      tooltip: hearted ? 'Remove heart' : 'Heart',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      icon: hearted
          ? badge
          : Icon(Symbols.favorite, size: 16, color: context.colors.textPrimary),
    );
  }
}

/// "▾ 3 replies" / "▴ Hide replies" under a comment.
class RepliesToggle extends StatelessWidget {
  const RepliesToggle({
    super.key,
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = expanded
        ? 'Hide replies'
        : '$count ${count == 1 ? 'reply' : 'replies'}';
    return Padding(
      padding: const EdgeInsets.only(left: 48),
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: replyLinkColor(context),
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        icon: Icon(
          expanded ? Symbols.keyboard_arrow_up : Symbols.keyboard_arrow_down,
          size: 20,
        ),
        label: Text(label),
      ),
    );
  }
}

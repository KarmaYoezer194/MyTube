import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/utils/format_views.dart';
import '../../core/widgets/channel_avatar.dart';
import '../../data/models/video.dart';
import '../../data/repositories/comment_repository.dart';
import '../../data/repositories/user_repository.dart';
import 'comments_sheet.dart';

/// The rounded "Comments 1.2K" card on the watch page, showing the pinned
/// or most liked comment (or "Add a comment..." if there are none).
/// Tap = comments sheet.
///
/// The count comes from the video itself (`commentCount`), so the card only
/// reads ONE comment instead of all of them.
class CommentsPreviewCard extends ConsumerWidget {
  const CommentsPreviewCard({super.key, required this.video});

  final Video video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final count = video.commentCount;
    // Older videos have no counter yet: count once and save it.
    if (count == null) {
      Future.microtask(
        () => ref
            .read(commentRepositoryProvider)
            .fillMissingCommentCount(video.id),
      );
    }
    final top = ref
        .watch(
          topCommentProvider((
            videoId: video.id,
            count: count ?? 0,
            pinnedId: video.pinnedCommentId,
          )),
        )
        .value;
    final profile = ref.watch(myProfileProvider).value;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showCommentsSheet(context, video.id),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Comments',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (count != null)
                    Text(
                      formatCompactCount(count),
                      style: AppTextStyles.meta.copyWith(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (top != null)
                    ChannelAvatar(
                      name: top.displayName,
                      imageUrl: top.avatarUrl,
                      size: 24,
                    )
                  else
                    ChannelAvatar(
                      name: profile?.displayName ?? '',
                      imageUrl: profile?.avatarUrl ?? '',
                      color: profile?.avatarColorValue,
                      size: 24,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      top?.text ?? 'Add a comment...',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 13,
                        color: top == null
                            ? colors.textSecondary
                            : colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

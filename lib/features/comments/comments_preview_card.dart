import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/utils/format_views.dart';
import '../../core/widgets/channel_avatar.dart';
import '../../data/repositories/comment_repository.dart';
import '../../data/repositories/user_repository.dart';
import 'comments_sheet.dart';

/// The rounded "Comments 1.2K" card on the watch page, showing the top
/// comment (or "Add a comment..." if there are none). Tap = comments sheet.
class CommentsPreviewCard extends ConsumerWidget {
  const CommentsPreviewCard({super.key, required this.videoId});

  final String videoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final comments = ref.watch(commentsProvider(videoId)).value;
    final top = comments == null || comments.isEmpty
        ? null
        : sortComments(comments, CommentSort.top).first;
    final profile = ref.watch(myProfileProvider).value;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showCommentsSheet(context, videoId),
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
                  if (comments != null)
                    Text(
                      formatCompactCount(comments.length),
                      style: AppTextStyles.meta
                          .copyWith(color: colors.textSecondary, fontSize: 13),
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

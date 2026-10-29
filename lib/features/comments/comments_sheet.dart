import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/utils/format_views.dart';
import '../../core/utils/time_ago.dart';
import '../../core/widgets/category_chip.dart';
import '../../core/widgets/channel_avatar.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/ensure_profile.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/comment.dart';
import '../../data/repositories/comment_repository.dart';
import '../../data/repositories/user_repository.dart';

/// Opens the comments of a video in a bottom sheet you can drag taller or
/// shorter (or down to close).
Future<void> showCommentsSheet(BuildContext context, String videoId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => _CommentsSheet(
        videoId: videoId,
        scrollController: scrollController,
      ),
    ),
  );
}

class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet({required this.videoId, required this.scrollController});

  final String videoId;

  /// Given by DraggableScrollableSheet: scrolling the list at its top
  /// drags the whole sheet.
  final ScrollController scrollController;

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  CommentSort _sort = CommentSort.top;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Snackbars shown INSIDE the sheet (see the ScaffoldMessenger in build).
  void _showMessage(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _post(BuildContext context) async {
    final text = _input.text.trim();
    if (text.isEmpty) return;

    // First comment ever: ask for a name and create the profile.
    final author = await ensureProfile(context, ref);
    if (author == null || !context.mounted) return;

    final posting = ref.read(commentRepositoryProvider).addComment(
          videoId: widget.videoId,
          author: author,
          text: text,
        );

    // It's already in the list (Firestore shows local changes at once).
    // Switch to Newest and scroll up so you see it on top.
    _input.clear();
    _focus.unfocus();
    setState(() => _sort = CommentSort.newest);
    if (widget.scrollController.hasClients) {
      widget.scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    try {
      await posting;
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, "Couldn't post. Check your internet connection.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final commentsAsync = ref.watch(commentsProvider(widget.videoId));
    final likedIds =
        ref.watch(likedCommentIdsProvider(widget.videoId)).value ?? const {};
    final profile = ref.watch(myProfileProvider).value;
    final count = commentsAsync.value?.length;

    // Its own ScaffoldMessenger + Scaffold, so snackbars appear on the
    // sheet instead of behind it.
    return ScaffoldMessenger(
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  controller: widget.scrollController,
                  slivers: [
                    // ---- Header: title, count, close, sort chips ----
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                        child: Row(
                          children: [
                            Text(
                              'Comments',
                              style: AppTextStyles.sectionHeader
                                  .copyWith(color: colors.textPrimary),
                            ),
                            const SizedBox(width: 8),
                            if (count != null)
                              Text(
                                formatCompactCount(count),
                                style: TextStyle(
                                  fontSize: 15,
                                  color: colors.textSecondary,
                                ),
                              ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Close',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Symbols.close),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: Row(
                          children: [
                            CategoryChip(
                              label: 'Top',
                              selected: _sort == CommentSort.top,
                              onTap: () =>
                                  setState(() => _sort = CommentSort.top),
                            ),
                            const SizedBox(width: 8),
                            CategoryChip(
                              label: 'Newest',
                              selected: _sort == CommentSort.newest,
                              onTap: () =>
                                  setState(() => _sort = CommentSort.newest),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: Divider()),

                    // ---- The comments ----
                    ...commentsAsync.when(
                      loading: () => [
                        SliverList.builder(
                          itemCount: 4,
                          itemBuilder: (context, index) =>
                              const _CommentSkeleton(),
                        ),
                      ],
                      error: (error, stackTrace) => [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyState(
                            icon: Symbols.cloud_off,
                            title: "Couldn't load comments",
                            message: 'Check your internet connection.',
                            actionLabel: 'Retry',
                            onAction: () => ref.invalidate(
                                commentsProvider(widget.videoId)),
                          ),
                        ),
                      ],
                      data: (comments) {
                        if (comments.isEmpty) {
                          return [
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: EmptyState(
                                icon: Symbols.chat_bubble,
                                title: 'No comments yet',
                                message: 'Be the first to say something!',
                                actionLabel: 'Add a comment',
                                onAction: _focus.requestFocus,
                              ),
                            ),
                          ];
                        }
                        final sorted = sortComments(comments, _sort);
                        return [
                          SliverList.builder(
                            itemCount: sorted.length,
                            itemBuilder: (context, index) {
                              final comment = sorted[index];
                              return _CommentTile(
                                key: ValueKey(comment.id),
                                comment: comment,
                                liked: likedIds.contains(comment.id),
                                onLike: (liked) => ref
                                    .read(commentRepositoryProvider)
                                    .setCommentLiked(
                                      videoId: widget.videoId,
                                      commentId: comment.id,
                                      liked: liked,
                                    )
                                    .catchError((Object _) {
                                  if (context.mounted) {
                                    _showMessage(
                                      context,
                                      "Couldn't save. Check your internet "
                                      'connection.',
                                    );
                                  }
                                }),
                                onReply: () => _showMessage(
                                    context, 'Replies are coming soon'),
                              );
                            },
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                        ];
                      },
                    ),
                  ],
                ),
              ),

              // ---- Input: my avatar + "Add a comment..." + send ----
              const Divider(),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  8,
                  4,
                  8 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Row(
                  children: [
                    ChannelAvatar(
                      name: profile?.displayName ?? '',
                      imageUrl: profile?.avatarUrl ?? '',
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _input,
                        focusNode: _focus,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 500,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          counterText: '', // hide the "0/500"
                          isDense: true,
                          filled: true,
                          fillColor: colors.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Post',
                      onPressed: _input.text.trim().isEmpty
                          ? null
                          : () => _post(context),
                      icon: const Icon(Symbols.send, fill: 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One comment: avatar, "@handle · 3 days ago", text, 👍 count, Reply.
class _CommentTile extends StatelessWidget {
  const _CommentTile({
    super.key,
    required this.comment,
    required this.liked,
    required this.onLike,
    required this.onReply,
  });

  final Comment comment;
  final bool liked;
  final ValueChanged<bool> onLike;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final secondary = AppTextStyles.meta.copyWith(color: colors.textSecondary);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChannelAvatar(
            name: comment.displayName,
            imageUrl: comment.avatarUrl,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${comment.handle} · ${timeAgo(comment.createdAt)}',
                  style: secondary,
                ),
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
                    const SizedBox(width: 12),
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
        ],
      ),
    );
  }
}

/// Grey shape of a comment while loading.
class _CommentSkeleton extends StatelessWidget {
  const _CommentSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Skeleton(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 28, height: 28, circle: true),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 140, height: 12),
                  SizedBox(height: 8),
                  SkeletonBox(width: double.infinity, height: 14),
                  SizedBox(height: 6),
                  SkeletonBox(width: 200, height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

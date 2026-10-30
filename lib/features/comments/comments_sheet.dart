import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/utils/format_views.dart';
import '../../core/widgets/category_chip.dart';
import '../../core/widgets/channel_avatar.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/paged_footer.dart' show loadMoreWhenNearEnd;
import '../../core/widgets/skeleton.dart';
import '../../data/models/channel.dart';
import '../../data/models/comment.dart';
import '../../data/models/video.dart';
import '../../data/repositories/comment_repository.dart';
import '../../data/repositories/paged_comments.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/video_repository.dart';
import '../auth/require_account.dart';
import '../channel/channel_navigation.dart';
import 'widgets/comment_tile.dart';

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
      builder: (context, scrollController) =>
          _CommentsSheet(videoId: videoId, scrollController: scrollController),
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

  /// The comment or reply I'm answering (shows "Replying to …").
  Comment? _replyTo;

  /// My comment or reply whose text I'm changing (shows "Editing …").
  Comment? _editing;

  bool _sending = false;

  /// Comments whose replies are open.
  final _expanded = <String>{};

  /// The lists aren't live, so my own changes are kept here and shown on
  /// top of what was loaded: changed copies (likes, text, heart, reply
  /// count) and deleted ids.
  final _changed = <String, Comment>{};
  final _deleted = <String>{};

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _videoId => widget.videoId;

  CommentListArg get _listArg => (videoId: _videoId, sort: _sort);

  Video? get _video => ref.read(videoProvider(_videoId)).value;

  /// The latest version of [comment] (with my own changes).
  Comment _latest(Comment comment) => _changed[comment.id] ?? comment;

  /// Finds a loaded comment (not a reply) by id.
  Comment? _findComment(String id) {
    if (_changed[id] case final changed?) return changed;
    final pinnedId = _video?.pinnedCommentId ?? '';
    if (pinnedId == id) {
      final pinned = ref
          .read(pinnedCommentProvider((videoId: _videoId, commentId: id)))
          .value;
      if (pinned != null) return pinned;
    }
    for (final comment in ref.read(commentListProvider(_listArg)).items) {
      if (comment.id == id) return comment;
    }
    return null;
  }

  void _remember(Comment comment) =>
      setState(() => _changed[comment.id] = comment);

  /// Snackbars shown INSIDE the sheet (see the ScaffoldMessenger in build).
  void _showMessage(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _clearInput() {
    _input.clear();
    _focus.unfocus();
    setState(() {
      _replyTo = null;
      _editing = null;
    });
  }

  // ---------------- Actions ----------------

  void _startReply(BuildContext context, Comment comment) {
    if (!checkSignedIn(context, ref, reason: SignInReason.comment)) return;
    setState(() {
      _editing = null;
      _replyTo = comment;
    });
    _input
      ..text = replyPrefill(comment)
      ..selection = TextSelection.collapsed(offset: _input.text.length);
    _focus.requestFocus();
  }

  void _startEdit(Comment comment) {
    setState(() {
      _replyTo = null;
      _editing = comment;
    });
    _input
      ..text = comment.text
      ..selection = TextSelection.collapsed(offset: comment.text.length);
    _focus.requestFocus();
  }

  Future<void> _submit(BuildContext context) async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final repository = ref.read(commentRepositoryProvider);

    // ---- Saving an edit ----
    if (_editing case final editing?) {
      setState(() => _sending = true);
      try {
        await repository
            .editComment(videoId: _videoId, comment: editing, text: text)
            .timeout(const Duration(seconds: 15));
        _remember(_latest(editing).copyWith(text: text, edited: true));
        _clearInput();
      } catch (_) {
        if (context.mounted) {
          _showMessage(
            context,
            "Couldn't save. Check your internet connection.",
          );
        }
      } finally {
        if (mounted) setState(() => _sending = false);
      }
      return;
    }

    // ---- Posting a comment or reply (needs an account) ----
    final author = await requireAccount(
      context,
      ref,
      reason: SignInReason.comment,
    );
    if (author == null || !context.mounted) return;

    final replyTo = _replyTo;
    setState(() => _sending = true);
    try {
      if (replyTo == null) {
        final comment = await repository
            .addComment(videoId: _videoId, author: author, text: text)
            .timeout(const Duration(seconds: 15));
        _clearInput();
        // Show it on top: in Newest, or switch to Newest (which then
        // loads fresh and already includes it).
        if (_sort == CommentSort.newest) {
          ref.read(commentListProvider(_listArg).notifier).insertFirst(comment);
        } else {
          setState(() => _sort = CommentSort.newest);
        }
        if (widget.scrollController.hasClients) {
          widget.scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      } else {
        // Replies always go into the thread of the top comment.
        final parentId = replyTo.isReply ? replyTo.parentId : replyTo.id;
        final reply = await repository
            .addReply(
              videoId: _videoId,
              parentId: parentId,
              author: author,
              text: text,
            )
            .timeout(const Duration(seconds: 15));
        _clearInput();
        if (_findComment(parentId) case final parent?) {
          _remember(parent.copyWith(replyCount: parent.replyCount + 1));
        }
        if (_expanded.contains(parentId)) {
          ref
              .read(
                repliesProvider((
                  videoId: _videoId,
                  commentId: parentId,
                )).notifier,
              )
              .append(reply);
        } else {
          // Opening the thread loads the replies, including the new one.
          setState(() => _expanded.add(parentId));
        }
      }
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, "Couldn't post. Check your internet connection.");
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _like(BuildContext context, Comment comment, bool liked) async {
    if (!checkSignedIn(context, ref, reason: SignInReason.likeComment)) return;
    final before = _latest(comment);
    // Show the new count at once; undo it if saving fails.
    _remember(
      before.copyWith(
        likes: (before.likes + (liked ? 1 : -1)).clamp(0, 1 << 31),
      ),
    );
    try {
      await ref
          .read(commentRepositoryProvider)
          .setCommentLiked(videoId: _videoId, comment: comment, liked: liked);
    } catch (_) {
      _remember(before);
      if (context.mounted) {
        _showMessage(context, "Couldn't save. Check your internet connection.");
      }
    }
  }

  Future<void> _toggleHeart(BuildContext context, Comment comment) async {
    final before = _latest(comment);
    _remember(before.copyWith(hearted: !before.hearted));
    try {
      await ref
          .read(commentRepositoryProvider)
          .setHearted(
            videoId: _videoId,
            comment: comment,
            hearted: !before.hearted,
          );
    } catch (_) {
      _remember(before);
      if (context.mounted) {
        _showMessage(context, "Couldn't save. Check your internet connection.");
      }
    }
  }

  Future<void> _setPinned(BuildContext context, String commentId) async {
    try {
      await ref
          .read(commentRepositoryProvider)
          .setPinned(videoId: _videoId, commentId: commentId);
      if (context.mounted) {
        _showMessage(
          context,
          commentId.isEmpty ? 'Comment unpinned' : 'Comment pinned',
        );
      }
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, "Couldn't save. Check your internet connection.");
      }
    }
  }

  Future<void> _delete(BuildContext context, Comment comment) async {
    final hasReplies = !comment.isReply && _latest(comment).replyCount > 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(comment.isReply ? 'Delete reply?' : 'Delete comment?'),
        content: Text(
          hasReplies
              ? 'Your comment and its replies will be deleted for good.'
              : 'It will be deleted for good.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final video = _video;
    final parent = comment.isReply ? _findComment(comment.parentId) : null;
    try {
      await ref
          .read(commentRepositoryProvider)
          .deleteComment(
            videoId: _videoId,
            comment: comment,
            knownCommentCount: video?.commentCount,
            knownReplyCount: parent?.replyCount,
          )
          .timeout(const Duration(seconds: 15));
      setState(() => _deleted.add(comment.id));
      if (parent != null) {
        _remember(
          parent.copyWith(
            replyCount: (parent.replyCount - 1).clamp(0, 1 << 31),
          ),
        );
      }
      // My own pinned comment is gone: unpin it.
      if (video != null &&
          video.pinnedCommentId == comment.id &&
          _isOwner(video)) {
        await ref
            .read(commentRepositoryProvider)
            .setPinned(videoId: _videoId, commentId: '');
      }
      if (context.mounted) {
        _showMessage(
          context,
          comment.isReply ? 'Reply deleted' : 'Comment deleted',
        );
      }
    } catch (_) {
      if (context.mounted) {
        _showMessage(
          context,
          "Couldn't delete. Check your internet connection.",
        );
      }
    }
  }

  bool _isOwner(Video? video) =>
      video != null &&
      ref.read(isSignedInProvider) &&
      video.uploaderUid == ref.read(currentUidProvider);

  /// The ⋮ menu: Pin (uploader), Edit and Delete (my own).
  Future<void> _showMenu(
    BuildContext context,
    Comment comment, {
    required bool mine,
    required bool canPin,
    required bool pinned,
  }) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canPin)
              ListTile(
                leading: const Icon(Symbols.push_pin),
                title: Text(pinned ? 'Unpin' : 'Pin'),
                onTap: () => Navigator.pop(sheetContext, 'pin'),
              ),
            if (mine) ...[
              ListTile(
                leading: const Icon(Symbols.edit),
                title: const Text('Edit'),
                onTap: () => Navigator.pop(sheetContext, 'edit'),
              ),
              ListTile(
                leading: const Icon(Symbols.delete),
                title: const Text('Delete'),
                onTap: () => Navigator.pop(sheetContext, 'delete'),
              ),
            ],
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'pin':
        await _setPinned(context, pinned ? '' : comment.id);
      case 'edit':
        _startEdit(_latest(comment));
      case 'delete':
        await _delete(context, _latest(comment));
    }
  }

  // ---------------- Building ----------------

  /// One comment or reply row, wired to the actions above.
  Widget _tile(BuildContext context, Comment loaded, {bool pinned = false}) {
    final comment = _latest(loaded);
    final video = ref.watch(videoProvider(_videoId)).value;
    final likedIds =
        ref.watch(likedCommentIdsProvider(_videoId)).value ?? const {};
    final myUid = ref.watch(currentUidProvider);
    final signedIn = ref.watch(isSignedInProvider);
    final isOwner = signedIn && video != null && video.uploaderUid == myUid;
    final mine = signedIn && comment.uid == myUid;
    final canPin = isOwner && !comment.isReply;

    return CommentTile(
      key: ValueKey('${pinned ? 'pinned-' : ''}${comment.id}'),
      comment: comment,
      liked: likedIds.contains(comment.id),
      pinned: pinned,
      creatorName: video?.channelName ?? '',
      byCreator: video != null && comment.uid == video.uploaderUid,
      onLike: (liked) => _like(context, comment, liked),
      onReply: () => _startReply(context, comment),
      onOpenChannel: () {
        openChannel(context, ref, Channel.idForUser(comment.uid));
        Navigator.of(context).pop();
      },
      onHeart: isOwner ? () => _toggleHeart(context, comment) : null,
      onMore: (mine || canPin)
          ? () => _showMenu(
              context,
              comment,
              mine: mine,
              canPin: canPin,
              pinned: video?.pinnedCommentId == comment.id,
            )
          : null,
    );
  }

  /// A comment, its "N replies" toggle and (when open) its replies.
  Widget _thread(BuildContext context, Comment loaded, {bool pinned = false}) {
    final comment = _latest(loaded);
    final expanded = _expanded.contains(comment.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tile(context, comment, pinned: pinned),
        if (comment.replyCount > 0 || expanded)
          RepliesToggle(
            count: comment.replyCount,
            expanded: expanded,
            onTap: () => setState(() {
              if (!_expanded.remove(comment.id)) _expanded.add(comment.id);
            }),
          ),
        if (expanded)
          _RepliesList(
            arg: (videoId: _videoId, commentId: comment.id),
            hidden: _deleted,
            buildTile: (reply) => _tile(context, reply),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final video = ref.watch(videoProvider(_videoId)).value;
    // Older videos have no counter yet: count once and save it.
    if (video != null && video.commentCount == null) {
      Future.microtask(
        () => ref
            .read(commentRepositoryProvider)
            .fillMissingCommentCount(_videoId),
      );
    }
    final page = ref.watch(commentListProvider(_listArg));
    final pinnedId = video?.pinnedCommentId ?? '';
    final pinned = pinnedId.isEmpty
        ? null
        : ref
              .watch(
                pinnedCommentProvider((videoId: _videoId, commentId: pinnedId)),
              )
              .value;
    final showPinned = pinned != null && !_deleted.contains(pinned.id);
    final comments = page.items
        .where((c) => c.id != pinnedId && !_deleted.contains(c.id))
        .toList();
    final isSignedIn = ref.watch(isSignedInProvider);
    // Guests show the grey "person" avatar next to the comment box.
    final profile = isSignedIn ? ref.watch(myProfileProvider).value : null;
    final count = video?.commentCount;

    // Its own ScaffoldMessenger + Scaffold, so snackbars appear on the
    // sheet instead of behind it.
    return ScaffoldMessenger(
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) => loadMoreWhenNearEnd(
                    notification,
                    ref.read(commentListProvider(_listArg).notifier).loadMore,
                  ),
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
                                style: AppTextStyles.sectionHeader.copyWith(
                                  color: colors.textPrimary,
                                ),
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
                      if (page.isFirstLoad)
                        SliverList.builder(
                          itemCount: 4,
                          itemBuilder: (context, index) =>
                              const _CommentSkeleton(),
                        )
                      else if (page.error != null && page.items.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyState(
                            icon: Symbols.cloud_off,
                            title: "Couldn't load comments",
                            message: 'Check your internet connection.',
                            actionLabel: 'Retry',
                            onAction: () =>
                                ref.invalidate(commentListProvider(_listArg)),
                          ),
                        )
                      else if (comments.isEmpty && !showPinned && !page.hasMore)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyState(
                            icon: Symbols.chat_bubble,
                            title: 'No comments yet',
                            message: 'Be the first to say something!',
                            actionLabel: 'Add a comment',
                            onAction: () {
                              if (checkSignedIn(
                                context,
                                ref,
                                reason: SignInReason.comment,
                              )) {
                                _focus.requestFocus();
                              }
                            },
                          ),
                        )
                      else ...[
                        if (showPinned)
                          SliverToBoxAdapter(
                            child: _thread(context, pinned, pinned: true),
                          ),
                        SliverList.builder(
                          itemCount: comments.length,
                          itemBuilder: (context, index) =>
                              _thread(context, comments[index]),
                        ),
                        SliverToBoxAdapter(
                          child: _CommentsFooter(
                            page: page,
                            onRetry: ref
                                .read(commentListProvider(_listArg).notifier)
                                .loadMore,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ---- "Replying to …" / "Editing …" bar ----
              const Divider(),
              if (_replyTo != null || _editing != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _editing != null
                              ? (_editing!.isReply
                                    ? 'Editing your reply'
                                    : 'Editing your comment')
                              : 'Replying to ${_replyTo!.handle}',
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.meta.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cancel',
                        visualDensity: VisualDensity.compact,
                        onPressed: _clearInput,
                        icon: const Icon(Symbols.close, size: 18),
                      ),
                    ],
                  ),
                ),

              // ---- Input: my avatar + "Add a comment..." + send ----
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
                      color: profile?.avatarColorValue,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _input,
                        focusNode: _focus,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 1000,
                        // Guests tapping the box get the sign-in sheet
                        // (like YouTube), instead of typing for nothing.
                        readOnly: !isSignedIn,
                        onTap: () {
                          if (!isSignedIn) {
                            checkSignedIn(
                              context,
                              ref,
                              reason: SignInReason.comment,
                            );
                          }
                        },
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: _replyTo != null
                              ? 'Add a reply...'
                              : 'Add a comment...',
                          counterText: '', // hide the "0/1000"
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
                    if (_sending)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    else
                      IconButton(
                        tooltip: _editing != null ? 'Save' : 'Post',
                        onPressed: _input.text.trim().isEmpty
                            ? null
                            : () => _submit(context),
                        icon: Icon(
                          _editing != null ? Symbols.check : Symbols.send,
                          fill: 1,
                        ),
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

/// The open replies of one comment, with "Show more replies".
class _RepliesList extends ConsumerWidget {
  const _RepliesList({
    required this.arg,
    required this.hidden,
    required this.buildTile,
  });

  final RepliesArg arg;

  /// Ids of replies I deleted.
  final Set<String> hidden;
  final Widget Function(Comment reply) buildTile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(repliesProvider(arg));
    final notifier = ref.read(repliesProvider(arg).notifier);
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final reply in page.items)
          if (!hidden.contains(reply.id)) buildTile(reply),
        if (page.isLoading)
          const Padding(
            padding: EdgeInsets.fromLTRB(64, 8, 0, 8),
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (page.error != null)
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: TextButton(
              onPressed: notifier.loadMore,
              style: TextButton.styleFrom(foregroundColor: colors.textPrimary),
              child: const Text("Couldn't load replies. Retry"),
            ),
          )
        else if (page.hasMore)
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: TextButton.icon(
              onPressed: notifier.loadMore,
              style: TextButton.styleFrom(
                foregroundColor: replyLinkColor(context),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Symbols.subdirectory_arrow_right, size: 18),
              label: const Text('Show more replies'),
            ),
          ),
      ],
    );
  }
}

/// The bottom of the list: a spinner while the next page loads, or Retry.
class _CommentsFooter extends StatelessWidget {
  const _CommentsFooter({required this.page, required this.onRetry});

  final PagedComments page;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (page.error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Column(
          children: [
            Text(
              "Couldn't load more comments.",
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (page.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    return const SizedBox(height: 24);
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

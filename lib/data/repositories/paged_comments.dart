import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/comment.dart';
import 'comment_repository.dart';

/// A list of comments (or replies) that loads one page at a time.
@immutable
class PagedComments {
  const PagedComments({
    this.items = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  final List<Comment> items;

  /// A page is being loaded right now.
  final bool isLoading;

  /// false once the last page has been loaded.
  final bool hasMore;

  /// Why the last page failed (shown with a Retry button), or null.
  final Object? error;

  /// Nothing loaded yet, and still loading.
  bool get isFirstLoad => items.isEmpty && isLoading;

  /// Loaded everything and there is nothing.
  bool get isEmpty => items.isEmpty && !hasMore && error == null;

  PagedComments withItems(List<Comment> items) => PagedComments(
    items: items,
    isLoading: isLoading,
    hasMore: hasMore,
    error: error,
  );
}

/// Adds the [incoming] comments that aren't in [current] yet, at the end.
/// (A comment you just posted can come back in a later page.)
List<Comment> mergeById(List<Comment> current, Iterable<Comment> incoming) {
  final known = {for (final comment in current) comment.id};
  return [...current, ...incoming.where((comment) => known.add(comment.id))];
}

/// Loads a Firestore query page by page, like PagedVideosController.
///
/// The list is NOT live (that would mean reading every comment again on
/// each change). Instead, my own changes (post, edit, delete, like) are
/// added to the list right away with [insertFirst] and [append] (the
/// comments screen keeps edits, likes and deletes on top of the list).
abstract class PagedCommentsController extends Notifier<PagedComments> {
  int get pageSize;

  DocumentSnapshot<Map<String, dynamic>>? _last;
  bool _busy = false;
  int _generation = 0;

  /// The query to page through (without limit).
  Query<Map<String, dynamic>> buildQuery();

  @override
  PagedComments build() {
    _last = null;
    _busy = false;
    final generation = ++_generation;
    Future.microtask(() {
      if (generation == _generation) loadMore();
    });
    return const PagedComments(isLoading: true);
  }

  /// Loads the next page. Does nothing while loading or after the last page.
  Future<void> loadMore() async {
    if (_busy || !state.hasMore) return;
    _busy = true;
    final generation = _generation;
    state = PagedComments(items: state.items, isLoading: true);
    try {
      var page = buildQuery().limit(pageSize);
      if (_last != null) page = page.startAfterDocument(_last!);
      final snapshot = await page.get();
      if (!ref.mounted || generation != _generation) return;
      if (snapshot.docs.isNotEmpty) _last = snapshot.docs.last;
      state = PagedComments(
        items: mergeById(state.items, snapshot.docs.map(Comment.fromFirestore)),
        hasMore: snapshot.docs.length == pageSize,
      );
    } catch (error) {
      // A missing index shows up here, with a link to create it.
      debugPrint('PAGED COMMENTS failed: $error');
      if (!ref.mounted || generation != _generation) return;
      state = PagedComments(items: state.items, error: error);
    } finally {
      if (generation == _generation) _busy = false;
    }
  }

  /// Puts [comment] at the top (a comment I just posted).
  void insertFirst(Comment comment) => state = state.withItems([
    comment,
    ...state.items.where((c) => c.id != comment.id),
  ]);

  /// Puts [comment] at the end (a reply I just posted).
  void append(Comment comment) =>
      state = state.withItems(mergeById(state.items, [comment]));
}

typedef CommentListArg = ({String videoId, CommentSort sort});

/// The comments of a video, 20 at a time, Top or Newest.
class CommentListController extends PagedCommentsController {
  CommentListController(this.arg);

  final CommentListArg arg;

  @override
  int get pageSize => 20;

  @override
  Query<Map<String, dynamic>> buildQuery() =>
      ref.read(commentRepositoryProvider).commentsQuery(arg.videoId, arg.sort);
}

final commentListProvider = NotifierProvider.autoDispose
    .family<CommentListController, PagedComments, CommentListArg>(
      CommentListController.new,
    );

typedef RepliesArg = ({String videoId, String commentId});

/// The replies of one comment, 10 at a time ("Show more replies").
class RepliesController extends PagedCommentsController {
  RepliesController(this.arg);

  final RepliesArg arg;

  @override
  int get pageSize => 10;

  @override
  Query<Map<String, dynamic>> buildQuery() => ref
      .read(commentRepositoryProvider)
      .repliesQuery(arg.videoId, arg.commentId);
}

final repliesProvider = NotifierProvider.autoDispose
    .family<RepliesController, PagedComments, RepliesArg>(
      RepliesController.new,
    );

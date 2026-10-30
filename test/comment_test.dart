import 'package:flutter_test/flutter_test.dart';
import 'package:mytube/data/models/comment.dart';
import 'package:mytube/data/models/video.dart';
import 'package:mytube/data/repositories/comment_repository.dart';
import 'package:mytube/data/repositories/paged_comments.dart';
import 'package:mytube/features/comments/widgets/comment_tile.dart';

Comment _comment(String id, {String parentId = '', bool edited = false}) =>
    Comment(
      id: id,
      uid: 'u1',
      displayName: 'Karma',
      handle: '@karma',
      avatarUrl: '',
      text: 'Hello',
      likes: 2,
      createdAt: DateTime(2026, 10, 1),
      parentId: parentId,
      edited: edited,
    );

void main() {
  group('Comment', () {
    test('fromMap fills safe defaults for old comments', () {
      final comment = Comment.fromMap('c1', {'text': 'Hi', 'likes': 3});
      expect(comment.text, 'Hi');
      expect(comment.likes, 3);
      expect(comment.replyCount, 0);
      expect(comment.edited, isFalse);
      expect(comment.hearted, isFalse);
      expect(comment.isReply, isFalse);
    });

    test('fromMap reads the new Phase 14 fields', () {
      final reply = Comment.fromMap('r1', {
        'replyCount': 4,
        'edited': true,
        'hearted': true,
      }, parentId: 'c1');
      expect(reply.isReply, isTrue);
      expect(reply.parentId, 'c1');
      expect(reply.replyCount, 4);
      expect(reply.edited, isTrue);
      expect(reply.hearted, isTrue);
    });

    test('only comments (not replies) get a reply counter', () {
      expect(_comment('c1').toFirestore()['replyCount'], 0);
      expect(
        _comment('r1', parentId: 'c1').toFirestore().containsKey('replyCount'),
        isFalse,
      );
    });

    test('a new comment always starts at 0 likes', () {
      expect(_comment('c1').toFirestore()['likes'], 0);
    });

    test('copyWith keeps everything it does not change', () {
      final changed = _comment(
        'r1',
        parentId: 'c1',
      ).copyWith(text: 'New', edited: true);
      expect(changed.text, 'New');
      expect(changed.edited, isTrue);
      expect(changed.id, 'r1');
      expect(changed.parentId, 'c1');
      expect(changed.likes, 2);
    });
  });

  group('counters', () {
    test('a counter never goes below 0', () {
      expect(exactCountOrNull(0, -1), 0);
      expect(exactCountOrNull(2, -5), 0);
    });

    test('normal changes use "add" (null = increment)', () {
      expect(exactCountOrNull(3, -1), isNull);
      expect(exactCountOrNull(0, 1), isNull);
      expect(exactCountOrNull(null, -1), isNull);
    });

    test('new videos start with 0 comments', () {
      final video = Video(
        id: 'v',
        title: 't',
        description: '',
        videoUrl: '',
        thumbnailUrl: '',
        durationSeconds: 0,
        channelId: 'c',
        channelName: 'C',
        channelAvatarUrl: '',
        subscriberCount: 0,
        views: 0,
        likes: 0,
        category: 'Other',
        isShort: false,
        uploaderUid: 'u',
        createdAt: DateTime(2026),
      );
      expect(video.commentCount, isNull);
      expect(video.pinnedCommentId, '');
      expect(video.toFirestore()['commentCount'], 0);
    });
  });

  test('replying to a reply mentions its author', () {
    expect(replyPrefill(_comment('c1')), '');
    expect(replyPrefill(_comment('r1', parentId: 'c1')), '@karma ');
  });

  test('mergeById adds only new comments, at the end', () {
    final merged = mergeById(
      [_comment('a'), _comment('b')],
      [_comment('b'), _comment('c')],
    );
    expect(merged.map((c) => c.id), ['a', 'b', 'c']);
  });

  test('the header shows (edited)', () {
    final now = DateTime(2026, 10, 4);
    expect(commentHeader(_comment('c1'), now: now), '@karma · 3 days ago');
    expect(
      commentHeader(_comment('c1', edited: true), now: now),
      '@karma · 3 days ago (edited)',
    );
  });
}

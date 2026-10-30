import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mytube/data/models/playlist.dart';
import 'package:mytube/data/models/video.dart';
import 'package:mytube/features/playlists/play_queue.dart';

void main() {
  group('Playlist', () {
    test('fromMap: safe defaults, private unless "public"', () {
      final playlist = Playlist.fromMap('p1', {'title': 'Mix'});
      expect(playlist.title, 'Mix');
      expect(playlist.isPrivate, isTrue);
      expect(playlist.videoIds, isEmpty);

      expect(Playlist.fromMap('p2', {'visibility': 'public'}).isPrivate, false);
      expect(Playlist.fromMap('p3', {'visibility': 'weird'}).isPrivate, true);
    });

    test('fromMap keeps only string video ids, in order', () {
      final playlist = Playlist.fromMap('p1', {
        'videoIds': ['b', 3, 'a', null],
      });
      expect(playlist.videoIds, ['b', 'a']);
      expect(playlist.contains('a'), isTrue);
      expect(playlist.contains('c'), isFalse);
    });

    test('is full at 200 videos', () {
      final ids = [for (var i = 0; i < Playlist.maxVideos; i++) 'v$i'];
      expect(Playlist.fromMap('p', {'videoIds': ids}).isFull, isTrue);
      expect(
        Playlist.fromMap('p', {'videoIds': ids.skip(1).toList()}).isFull,
        isFalse,
      );
    });

    test('built-in ids', () {
      expect(Playlist.isBuiltIn(Playlist.likedId), isTrue);
      expect(Playlist.isBuiltIn(Playlist.watchLaterId), isTrue);
      expect(Playlist.isBuiltIn('abc'), isFalse);
    });

    test('subtitle', () {
      expect(
        playlistSubtitle(isPrivate: true, count: 0),
        'Private · No videos',
      );
      expect(playlistSubtitle(isPrivate: false, count: 1), 'Public · 1 video');
      expect(playlistSubtitle(isPrivate: true, count: 5), 'Private · 5 videos');
    });
  });

  group('moveItem (drag to reorder)', () {
    final items = ['a', 'b', 'c', 'd'];

    test(
      'moves down',
      () => expect(moveItem(items, 0, 2), ['b', 'c', 'a', 'd']),
    );
    test('moves up', () => expect(moveItem(items, 3, 1), ['a', 'd', 'b', 'c']));
    test(
      'to the end',
      () => expect(moveItem(items, 1, 3), ['a', 'c', 'd', 'b']),
    );
    test('same place', () => expect(moveItem(items, 2, 2), items));
    test(
      'bad index changes nothing',
      () => expect(moveItem(items, 9, 0), items),
    );
    test('does not change the original list', () {
      moveItem(items, 0, 3);
      expect(items, ['a', 'b', 'c', 'd']);
    });
  });

  group('play queue', () {
    test('next video in the playlist, null at the end', () {
      const ids = ['a', 'b', 'c'];
      expect(nextInQueue(ids, 'a'), 'b');
      expect(nextInQueue(ids, 'b'), 'c');
      expect(nextInQueue(ids, 'c'), isNull);
      expect(nextInQueue(ids, 'x'), isNull);
    });

    test('shuffle keeps every video and puts the chosen one first', () {
      const ids = ['a', 'b', 'c', 'd', 'e'];
      final shuffled = shuffledIds(ids, first: 'd', random: Random(1));
      expect(shuffled.first, 'd');
      expect(shuffled.toSet(), ids.toSet());
      expect(shuffled.length, ids.length);
    });

    test('next video skips what was already played (no A-B-A loop)', () {
      Video v(String id) => Video(
        id: id,
        title: id,
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
      final upNext = [v('a'), v('b'), v('c')];
      expect(pickNextUnplayed(upNext, const [])?.id, 'a');
      expect(pickNextUnplayed(upNext, const ['a'])?.id, 'b');
      expect(pickNextUnplayed(upNext, const ['a', 'b'])?.id, 'c');
      // Everything played: start over with the best match.
      expect(pickNextUnplayed(upNext, const ['a', 'b', 'c'])?.id, 'a');
      expect(pickNextUnplayed(const [], const ['a']), isNull);
    });

    test('PlayQueue finds videos', () {
      const queue = PlayQueue(
        playlistId: 'p',
        title: 'Mix',
        videoIds: ['a', 'b'],
      );
      expect(queue.contains('b'), isTrue);
      expect(queue.indexOf('b'), 1);
      expect(queue.contains('z'), isFalse);
    });
  });
}

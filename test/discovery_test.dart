import 'package:flutter_test/flutter_test.dart';
import 'package:mytube/core/utils/search_keywords.dart';
import 'package:mytube/data/models/video.dart';
import 'package:mytube/features/discovery/discovery_providers.dart';
import 'package:mytube/features/discovery/recommendations.dart';

Video _video(
  String id, {
  String? title,
  String channelId = 'c1',
  String channelName = 'Gearhead Garage',
  String category = 'Cars',
  int views = 0,
  bool isShort = false,
  String visibility = 'public',
}) => Video(
  id: id,
  title: title ?? id,
  description: '',
  videoUrl: '',
  thumbnailUrl: '',
  durationSeconds: 0,
  channelId: channelId,
  channelName: channelName,
  channelAvatarUrl: '',
  subscriberCount: 0,
  views: views,
  likes: 0,
  category: category,
  isShort: isShort,
  uploaderUid: 'u',
  createdAt: DateTime(2026),
  visibility: visibility,
);

void main() {
  group('search keywords', () {
    test('words: lower case, no punctuation', () {
      expect(searchWords('Sci-Fi: Tears of Steel!'), [
        'sci',
        'fi',
        'tears',
        'of',
        'steel',
      ]);
      expect(searchWords('   '), isEmpty);
    });

    test('every beginning of every word, no repeats', () {
      expect(buildKeywords(['Big Buck Bunny']), [
        'b',
        'bi',
        'big',
        'bu',
        'buc',
        'buck',
        'bun',
        'bunn',
        'bunny',
      ]);
    });

    test('long words stop at 15 letters, and there are at most 200', () {
      final long = buildKeywords(['abcdefghijklmnopqrstuvwxyz']);
      expect(long.last, 'abcdefghijklmno');
      final many = buildKeywords([
        List.generate(50, (i) => 'word$i${'x' * 10}').join(' '),
      ]);
      expect(many.length, maxKeywords);
    });

    test('a video can be found by its channel and category too', () {
      final keywords = videoKeywords(
        title: 'Rally drone',
        channelName: 'Gearhead Garage',
        category: 'Cars',
      );
      expect(keywords, containsAll(['ral', 'gear', 'garage', 'car']));
    });

    test('Firestore is asked for the longest word', () {
      expect(searchTerm('big bunny'), 'bunny');
      expect(searchTerm('  '), isNull);
      expect(searchTerm('a' * 30), 'a' * maxPrefixLength);
    });

    test('every query word must start a word', () {
      expect(matchesQuery(['Big Buck Bunny'], 'bun big'), isTrue);
      expect(matchesQuery(['Big Buck Bunny'], 'bunny sintel'), isFalse);
      expect(matchesQuery(['Big Buck Bunny'], 'unny'), isFalse);
    });

    test('relevance: whole query in the title first', () {
      expect(
        relevanceScore('Big Buck Bunny', 'big buck'),
        greaterThan(relevanceScore('A big day with buck', 'big buck')),
      );
      expect(relevanceScore('Sintel', ''), 0);
    });
  });

  group('visibleSearchResults', () {
    final a = _video('a', title: 'Night drive', views: 10);
    final b = _video('b', title: 'Drive at night in the snow', views: 50);
    final hidden = _video('h', title: 'Night drive 2', channelId: 'bad');

    test('relevance puts the best title match first', () {
      final results = visibleSearchResults(
        [b, a],
        'night drive',
        SearchSort.relevance,
        const TasteProfile(),
      );
      expect(results.map((v) => v.id), ['a', 'b']);
    });

    test('date / views keep the Firestore order', () {
      final results = visibleSearchResults(
        [b, a],
        'night drive',
        SearchSort.views,
        const TasteProfile(),
      );
      expect(results.map((v) => v.id), ['b', 'a']);
    });

    test('hidden videos and channels are left out', () {
      final results = visibleSearchResults(
        [a, hidden],
        'night',
        SearchSort.date,
        const TasteProfile(hiddenChannelIds: {'bad'}, hiddenVideoIds: {'a'}),
      );
      expect(results, isEmpty);
    });

    test('all words must match', () {
      final results = visibleSearchResults(
        [a, b],
        'snow drive',
        SearchSort.date,
        const TasteProfile(),
      );
      expect(results.map((v) => v.id), ['b']);
    });
  });

  group('recommendations', () {
    final current = _video('now', channelId: 'c1', category: 'Cars');
    final sameChannel = _video('same', channelId: 'c1', category: 'Animation');
    final other = _video('other', channelId: 'c9', category: 'Sci-Fi');
    final popular = _video(
      'popular',
      channelId: 'c9',
      category: 'Sci-Fi',
      views: 1000000,
    );

    test('same channel beats an unrelated video', () {
      final list = recommend(
        [other, sameChannel],
        const TasteProfile(),
        current: current,
      );
      expect(list.first.id, 'same');
    });

    test('popular videos rank higher among equals', () {
      final list = recommend([other, popular], const TasteProfile());
      expect(list.first.id, 'popular');
    });

    test('subscriptions and favourite categories count', () {
      const taste = TasteProfile(
        subscribedChannelIds: {'c9'},
        categoryCounts: {'Sci-Fi': 3},
      );
      expect(
        recommendationScore(other, taste),
        greaterThan(recommendationScore(sameChannel, taste)),
      );
    });

    test('leaves out the current video, Shorts, unlisted and hidden', () {
      final list = recommend(
        [
          current,
          _video('short', isShort: true),
          _video('unlisted', visibility: 'unlisted'),
          _video('hidden'),
          other,
        ],
        const TasteProfile(hiddenVideoIds: {'hidden'}),
        current: current,
      );
      expect(list.map((v) => v.id), ['other']);
    });

    test('"unwatched only" skips what I watched', () {
      final list = recommend(
        [other, sameChannel],
        const TasteProfile(watchedIds: {'other'}),
        unwatchedOnly: true,
      );
      expect(list.map((v) => v.id), ['same']);
    });

    test('countCategories', () {
      expect(countCategories([current, sameChannel, _video('x')]), {
        'Cars': 2,
        'Animation': 1,
      });
    });
  });

  test('new videos are saved with their search keywords', () {
    final map = _video('v', title: 'Snow forest drive').toFirestore();
    expect(map['keywords'], containsAll(['snow', 'for', 'drive', 'cars']));
  });
}

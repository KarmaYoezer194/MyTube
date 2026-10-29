import 'package:flutter_test/flutter_test.dart';
import 'package:mytube/core/theme/avatar_colors.dart';
import 'package:mytube/data/models/app_user.dart';
import 'package:mytube/data/models/channel.dart';
import 'package:mytube/data/models/video.dart';

void main() {
  group('Channel.fromMap', () {
    test('reads every field', () {
      final channel = Channel.fromMap('ev-weekly', {
        'name': 'EV Weekly',
        'handle': '@evweekly',
        'description': 'Electric cars',
        'bannerUrl': 'https://example.com/b.jpg',
        'avatarUrl': '',
        'avatarColor': 0xFF00897B,
        'subscriberCount': 286000,
        'ownerUid': 'seed',
      });
      expect(channel.id, 'ev-weekly');
      expect(channel.name, 'EV Weekly');
      expect(channel.handle, '@evweekly');
      expect(channel.subscriberCount, 286000);
      expect(channel.avatarColor, 0xFF00897B);
      expect(channel.isSeed, isTrue);
    });

    test('has safe defaults for a half-filled document', () {
      final channel = Channel.fromMap('x', {'name': 'Karma'});
      expect(channel.handle, '');
      expect(channel.description, '');
      expect(channel.subscriberCount, 0);
      expect(channel.avatarColor, avatarColorFor('Karma').toARGB32());
      expect(channel.isSeed, isFalse);
    });
  });

  test('idForUser', () {
    expect(Channel.idForUser('abc123'), 'user-abc123');
  });

  test('Channel.fromVideo uses the video channel fields', () {
    final video = Video(
      id: 'v1',
      title: 'T',
      description: '',
      videoUrl: '',
      thumbnailUrl: '',
      durationSeconds: 10,
      channelId: 'user-u1',
      channelName: 'Karma',
      channelAvatarUrl: '',
      subscriberCount: 3,
      views: 0,
      likes: 0,
      category: 'Other',
      isShort: false,
      uploaderUid: 'u1',
      createdAt: DateTime(2026),
      channelAvatarColor: 0xFF5E35B1,
    );
    final channel = Channel.fromVideo(video);
    expect(channel.id, 'user-u1');
    expect(channel.name, 'Karma');
    expect(channel.ownerUid, 'u1');
    expect(channel.subscriberCount, 3);
    expect(channel.avatarColor, 0xFF5E35B1);
  });

  test('Channel.fromProfile uses the account profile', () {
    final channel = Channel.fromProfile(
      AppUser(
        uid: 'u2',
        displayName: 'Mali',
        handle: '@mali1234',
        avatarUrl: '',
        avatarColor: 0xFFEF6C00,
        createdAt: DateTime(2026, 1, 2),
      ),
    );
    expect(channel.id, 'user-u2');
    expect(channel.name, 'Mali');
    expect(channel.handle, '@mali1234');
    expect(channel.subscriberCount, 0);
    expect(channel.ownerUid, 'u2');
  });

  group('normalizeHandle', () {
    test('adds one @, lower-cases and removes spaces', () {
      expect(normalizeHandle('Karma Yoezer'), '@karmayoezer');
      expect(normalizeHandle('@@Karma.Y'), '@karma.y');
      expect(normalizeHandle('  @abc  '), '@abc');
    });
  });

  group('handleProblem', () {
    test('accepts valid handles', () {
      expect(handleProblem('@abc'), isNull);
      expect(handleProblem('@karma.yoezer_4821-x'), isNull);
      expect(handleProblem('@${'a' * 30}'), isNull);
    });

    test('refuses short, long and odd handles', () {
      expect(handleProblem('@ab'), isNotNull);
      expect(handleProblem('@${'a' * 31}'), isNotNull);
      expect(handleProblem('@karma!'), isNotNull);
      expect(handleProblem('@Karma'), isNotNull);
      expect(handleProblem('@ไทย'), isNotNull);
    });
  });

  group('channelNameProblem', () {
    test('needs 1 to 50 characters', () {
      expect(channelNameProblem('Karma'), isNull);
      expect(channelNameProblem('   '), isNotNull);
      expect(channelNameProblem('a' * 51), isNotNull);
      expect(channelNameProblem('a' * 50), isNull);
    });
  });

  group('chunked', () {
    test('splits into parts of at most the size', () {
      final parts = chunked(List.generate(65, (i) => i), 30);
      expect(parts.map((p) => p.length), [30, 30, 5]);
      expect(parts.expand((p) => p).toList(), List.generate(65, (i) => i));
    });

    test('empty list gives no parts', () {
      expect(chunked(<int>[], 30), isEmpty);
    });
  });
}

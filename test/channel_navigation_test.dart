import 'package:flutter_test/flutter_test.dart';
import 'package:mytube/features/channel/channel_navigation.dart';

void main() {
  group('channelLocation', () {
    test('opens inside the current tab', () {
      expect(channelLocation('/home', 'ev-weekly'), '/home/channel/ev-weekly');
      expect(
        channelLocation('/home/search', 'ev-weekly'),
        '/home/channel/ev-weekly',
      );
      expect(
        channelLocation('/subscriptions', 'quick-clips'),
        '/subscriptions/channel/quick-clips',
      );
      expect(channelLocation('/you/history', 'x'), '/you/channel/x');
    });

    test('Shorts and unknown pages open in Home', () {
      expect(channelLocation('/shorts', 'x'), '/home/channel/x');
      expect(channelLocation('/', 'x'), '/home/channel/x');
      expect(channelLocation('/youtube', 'x'), '/home/channel/x');
    });

    test('does nothing when already on that channel', () {
      expect(channelLocation('/home/channel/x', 'x'), isNull);
      expect(channelLocation('/home/channel/x', 'y'), '/home/channel/y');
    });

    test('encodes the id', () {
      expect(channelLocation('/home', 'a b'), '/home/channel/a%20b');
    });
  });

  group('playlist pages', () {
    test('open inside the current tab too', () {
      expect(
        tabPageLocation('/home/channel/x', 'playlist', 'p1'),
        '/home/playlist/p1',
      );
      expect(tabPageLocation('/you', 'playlist', 'p1'), '/you/playlist/p1');
      expect(tabPageLocation('/shorts', 'playlist', 'p1'), '/home/playlist/p1');
    });

    test('does nothing when already on that playlist', () {
      expect(tabPageLocation('/you/playlist/p1', 'playlist', 'p1'), isNull);
    });
  });
}

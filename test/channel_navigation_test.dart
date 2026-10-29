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
}

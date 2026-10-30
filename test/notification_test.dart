import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytube/core/theme/app_theme.dart';
import 'package:mytube/data/models/app_notification.dart';
import 'package:mytube/data/repositories/notification_repository.dart';
import 'package:mytube/features/notifications/notifications_providers.dart';
import 'package:mytube/features/notifications/notifications_screen.dart';

AppNotification _n({
  NotificationType type = NotificationType.upload,
  bool read = false,
  bool isShort = false,
  String text = '',
}) => AppNotification(
  id: 'id',
  type: type,
  fromUid: 'u2',
  fromName: 'Karma',
  fromAvatarUrl: '',
  videoId: 'v1',
  videoTitle: 'My trip',
  thumbnailUrl: '',
  isShort: isShort,
  commentId: '',
  replyId: '',
  text: text,
  read: read,
  createdAt: DateTime.now(),
);

void main() {
  group('AppNotification', () {
    test('fromMap: safe defaults', () {
      final n = AppNotification.fromMap('x', const {});
      expect(n.type, NotificationType.upload);
      expect(n.read, isFalse);
      expect(n.fromName, '');
    });

    test('fromMap reads the type', () {
      expect(
        AppNotification.fromMap('x', {'type': 'reply', 'read': true}).type,
        NotificationType.reply,
      );
      expect(
        AppNotification.fromMap('x', {'type': 'nonsense'}).type,
        NotificationType.upload,
      );
    });

    test('messages', () {
      expect(_n().message, 'Karma uploaded: My trip');
      expect(_n(isShort: true).message, 'Karma posted a new Short: My trip');
      expect(
        _n(type: NotificationType.comment, text: 'Nice!').message,
        'Karma commented: "Nice!"',
      );
      expect(
        _n(type: NotificationType.reply, text: 'Thanks').message,
        'Karma replied to your comment: "Thanks"',
      );
    });

    test('ids say what it is about (so nothing is sent twice)', () {
      expect(AppNotification.uploadId('v1'), 'u_v1');
      expect(AppNotification.commentNotificationId('c1'), 'c_c1');
      expect(AppNotification.replyNotificationId('r1'), 'r_r1');
    });

    test('a new notification is unread and has a short text', () {
      final map = _n(text: 'x' * 500).toFirestore();
      expect(map['read'], isFalse);
      expect((map['text'] as String).length, AppNotification.maxText);
      expect(map.containsKey('fromAvatarColor'), isFalse);
    });
  });

  test('snippet keeps it on one line', () {
    expect(snippet('  hello\n\n  world  '), 'hello world');
  });

  test('badge label', () {
    expect(badgeLabel(0), '');
    expect(badgeLabel(3), '3');
    expect(badgeLabel(9), '9');
    expect(badgeLabel(10), '9+');
  });

  test('unread count', () {
    expect(unreadCount([_n(), _n(read: true), _n()]), 2);
    expect(unreadCount(const []), 0);
  });

  test('who gets notified', () {
    expect(shouldNotify(receiverUid: 'a', myUid: 'b'), isTrue);
    expect(shouldNotify(receiverUid: 'a', myUid: 'a'), isFalse);
    expect(shouldNotify(receiverUid: 'seed', myUid: 'b'), isFalse);
    expect(shouldNotify(receiverUid: '', myUid: 'b'), isFalse);
  });

  group('NotificationTile', () {
    Widget wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: child),
    );

    testWidgets('unread shows a blue dot, read does not', (tester) async {
      await tester.pumpWidget(
        wrap(NotificationTile(notification: _n(), onTap: () {}, onMore: () {})),
      );
      expect(find.byKey(const ValueKey('unread-dot')), findsOneWidget);

      await tester.pumpWidget(
        wrap(
          NotificationTile(
            notification: _n(read: true),
            onTap: () {},
            onMore: () {},
          ),
        ),
      );
      expect(find.byKey(const ValueKey('unread-dot')), findsNothing);
    });

    testWidgets('tap and ⋮ call back', (tester) async {
      var taps = 0, menus = 0;
      await tester.pumpWidget(
        wrap(
          NotificationTile(
            notification: _n(),
            onTap: () => taps++,
            onMore: () => menus++,
          ),
        ),
      );
      await tester.tap(find.text('Karma uploaded: My trip'));
      await tester.tap(find.byTooltip('More actions'));
      expect(taps, 1);
      expect(menus, 1);
    });
  });
}

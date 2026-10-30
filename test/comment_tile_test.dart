import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mytube/core/theme/app_theme.dart';
import 'package:mytube/data/models/comment.dart';
import 'package:mytube/features/comments/widgets/comment_tile.dart';

Comment _comment({bool edited = false, bool hearted = false}) => Comment(
  id: 'c1',
  uid: 'u1',
  displayName: 'Karma',
  handle: '@karma',
  avatarUrl: '',
  text: 'Nice video!',
  likes: 5,
  createdAt: DateTime.now(),
  edited: edited,
  hearted: hearted,
);

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  home: Scaffold(body: child),
);

Widget _tile({
  Comment? comment,
  bool pinned = false,
  VoidCallback? onHeart,
  VoidCallback? onMore,
  VoidCallback? onReply,
}) => _wrap(
  CommentTile(
    comment: comment ?? _comment(),
    liked: false,
    onLike: (_) {},
    onReply: onReply ?? () {},
    onOpenChannel: () {},
    creatorName: 'Creator',
    pinned: pinned,
    onHeart: onHeart,
    onMore: onMore,
  ),
);

void main() {
  testWidgets('shows the text, like count and (edited)', (tester) async {
    await tester.pumpWidget(_tile(comment: _comment(edited: true)));
    expect(find.text('Nice video!'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.textContaining('(edited)'), findsOneWidget);
  });

  testWidgets('a comment opened from a notification is highlighted', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        CommentTile(
          comment: _comment(),
          liked: false,
          onLike: (_) {},
          onReply: () {},
          onOpenChannel: () {},
          creatorName: 'Creator',
          highlighted: true,
        ),
      ),
    );
    expect(find.text('Highlighted comment'), findsOneWidget);
  });

  testWidgets('a pinned comment says who pinned it', (tester) async {
    await tester.pumpWidget(_tile(pinned: true));
    expect(find.text('Pinned by Creator'), findsOneWidget);
  });

  testWidgets('viewers only see a heart once it was given', (tester) async {
    await tester.pumpWidget(_tile());
    expect(find.byTooltip('Hearted by Creator'), findsNothing);

    await tester.pumpWidget(_tile(comment: _comment(hearted: true)));
    expect(find.byTooltip('Hearted by Creator'), findsOneWidget);
  });

  testWidgets('the uploader can tap the heart', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_tile(onHeart: () => taps++));
    await tester.tap(find.byTooltip('Heart'));
    expect(taps, 1);
  });

  testWidgets('no ⋮ menu when there is nothing to do', (tester) async {
    await tester.pumpWidget(_tile());
    expect(find.byIcon(Symbols.more_vert), findsNothing);

    var opened = 0;
    await tester.pumpWidget(_tile(onMore: () => opened++));
    await tester.tap(find.byTooltip('More'));
    expect(opened, 1);
  });

  testWidgets('Reply calls back', (tester) async {
    var replies = 0;
    await tester.pumpWidget(_tile(onReply: () => replies++));
    await tester.tap(find.text('Reply'));
    expect(replies, 1);
  });

  testWidgets('replies toggle labels', (tester) async {
    Widget toggle(int count, bool expanded) =>
        _wrap(RepliesToggle(count: count, expanded: expanded, onTap: () {}));
    await tester.pumpWidget(toggle(1, false));
    expect(find.text('1 reply'), findsOneWidget);
    await tester.pumpWidget(toggle(3, false));
    expect(find.text('3 replies'), findsOneWidget);
    await tester.pumpWidget(toggle(3, true));
    expect(find.text('Hide replies'), findsOneWidget);
  });
}

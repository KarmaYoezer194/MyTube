import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Quick structure checks of firestore.rules (the real check happens when
/// the rules are deployed). Catches unbalanced brackets and rules that
/// would open the database to everyone.
void main() {
  final rules = File('firestore.rules').readAsStringSync();
  // Drop comments so brackets in them don't count. (A comment starts with
  // `//` at the start of a line or after a space; `https://` is not one.)
  final comment = RegExp(r'(^|\s)//.*$', multiLine: true);
  final code = rules.replaceAll(comment, '');

  int count(String char) => char.allMatches(code).length;

  test('brackets are balanced', () {
    expect(count('{'), count('}'));
    expect(count('('), count(')'));
    expect(count('['), count(']'));
  });

  test('uses rules version 2', () {
    expect(code, contains("rules_version = '2';"));
  });

  test('nothing is open to everyone', () {
    expect(code, isNot(matches(RegExp(r'if\s+true\s*;'))));
    expect(code, isNot(contains('allow read, write;')));
  });

  test('every allow line ends a statement', () {
    final allows = RegExp(r'allow [^;]*?;', dotAll: true).allMatches(code);
    final starts = RegExp(r'\ballow\b').allMatches(code);
    expect(allows.length, starts.length);
  });

  test('channels and handles are protected', () {
    expect(code, contains('match /channels/{channelId}'));
    expect(code, contains('match /handles/{handle}'));
    expect(code, contains("onlyChanges(['subscriberCount'])"));
    expect(code, contains('allow delete: if false;'));
  });

  test('comments: replies, counters, edit, pin and heart are checked', () {
    expect(code, contains('match /replies/{replyId}'));
    expect(code, contains('function isCommentCountChange()'));
    expect(code, contains('function countIs(expected, actual)'));
    expect(code, contains("onlyChanges(['pinnedCommentId'])"));
    expect(code, contains("onlyChanges(['hearted'])"));
    expect(code, contains("onlyChanges(['text', 'edited', 'editedAt'])"));
    // Posting a comment or reply must move the video's counter.
    expect(
      RegExp(r'commentCountMovedBy\(videoId, 1\)').allMatches(code).length,
      2,
    );
  });

  test('playlists: only the owner changes them, private stays private', () {
    expect(code, contains('match /playlists/{playlistId}'));
    expect(code, contains("resource.data.visibility == 'public'"));
    expect(code, contains('d.videoIds.size() <= 200'));
    expect(
      code,
      contains("onlyChanges(['title', 'visibility', 'videoIds', 'updatedAt'])"),
    );
  });

  test('notifications: only for real events, only the receiver reads', () {
    expect(code, contains('match /notifications/{notificationId}'));
    expect(
      code,
      contains("notificationId == 'u_' + request.resource.data.videoId"),
    );
    expect(
      code,
      contains("notificationId == 'c_' + request.resource.data.commentId"),
    );
    expect(
      code,
      contains("notificationId == 'r_' + request.resource.data.replyId"),
    );
    expect(
      code,
      contains("allow update: if isMe(uid) && onlyChanges(['read'])"),
    );
    // A channel may only list its OWN subscribers.
    expect(code, contains('match /{path=**}/subscribed/{channelId}'));
    expect(
      code,
      contains("resource.data.channelId == 'user-' + request.auth.uid"),
    );
  });

  test('search keywords: owners update them, old documents fill in once', () {
    expect(code, contains('function isKeywordsFillIn()'));
    expect(code, contains("!('keywords' in resource.data)"));
    expect(code, contains('value.size() <= 200'));
  });

  test('guests can still keep history and add views', () {
    expect(code, contains('match /history/{videoId}'));
    expect(code, contains("onlyChanges(['views'])"));
  });
}

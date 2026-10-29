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

  test('guests can still keep history and add views', () {
    expect(code, contains('match /history/{videoId}'));
    expect(code, contains("onlyChanges(['views'])"));
  });
}

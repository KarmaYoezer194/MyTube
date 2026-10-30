import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytube/core/providers/shared_preferences_provider.dart';
import 'package:mytube/core/utils/app_links.dart';
import 'package:mytube/data/models/video.dart';
import 'package:mytube/data/repositories/report_repository.dart';
import 'package:mytube/features/watch/keyboard_shortcuts.dart';
import 'package:mytube/features/watch/playback_controller.dart';
import 'package:mytube/features/watch/widgets/playback_speed_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

Video _video(String id, {bool isShort = false}) => Video(
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
  isShort: isShort,
  uploaderUid: 'u',
  createdAt: DateTime(2026),
);

Future<ProviderContainer> _container(Map<String, Object> saved) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('links', () {
    test('watch, Short and channel paths', () {
      expect(watchPath('sintel'), '/watch?v=sintel');
      expect(shortPath('fire_juggling'), '/shorts/fire_juggling');
      expect(channelPath('@blender'), '/@blender');
      expect(channelPath('blender'), '/@blender');
      expect(videoPath(_video('a')), '/watch?v=a');
      expect(videoPath(_video('b', isShort: true)), '/shorts/b');
    });

    test('ids are encoded', () {
      expect(watchPath('a b&c'), '/watch?v=a+b%26c');
      expect(shortPath('a/b'), '/shorts/a%2Fb');
    });

    test('full link uses the #/ address style', () {
      expect(
        buildAppLink('http://localhost:5000', '/watch?v=x'),
        'http://localhost:5000/#/watch?v=x',
      );
    });
  });

  group('keyboard shortcuts', () {
    PlayerShortcut? action(LogicalKeyboardKey key, {bool shift = false}) =>
        shortcutFor(key, shift: shift)?.action;

    test('YouTube keys', () {
      expect(action(LogicalKeyboardKey.space), PlayerShortcut.playPause);
      expect(action(LogicalKeyboardKey.keyK), PlayerShortcut.playPause);
      expect(action(LogicalKeyboardKey.keyJ), PlayerShortcut.back10);
      expect(action(LogicalKeyboardKey.keyL), PlayerShortcut.forward10);
      expect(action(LogicalKeyboardKey.arrowLeft), PlayerShortcut.back5);
      expect(action(LogicalKeyboardKey.arrowUp), PlayerShortcut.volumeUp);
      expect(action(LogicalKeyboardKey.keyM), PlayerShortcut.mute);
      expect(action(LogicalKeyboardKey.keyF), PlayerShortcut.fullscreen);
      expect(action(LogicalKeyboardKey.keyI), PlayerShortcut.miniPlayer);
      expect(action(LogicalKeyboardKey.escape), PlayerShortcut.exitOrMinimize);
      expect(action(LogicalKeyboardKey.keyX), isNull);
    });

    test('Shift + N / P, and N alone does nothing', () {
      expect(action(LogicalKeyboardKey.keyN, shift: true), PlayerShortcut.next);
      expect(
        action(LogicalKeyboardKey.keyP, shift: true),
        PlayerShortcut.previous,
      );
      expect(action(LogicalKeyboardKey.keyN), isNull);
    });

    test('> < ? work as their own key or with Shift', () {
      expect(action(LogicalKeyboardKey.greater), PlayerShortcut.faster);
      expect(
        action(LogicalKeyboardKey.period, shift: true),
        PlayerShortcut.faster,
      );
      expect(
        action(LogicalKeyboardKey.comma, shift: true),
        PlayerShortcut.slower,
      );
      expect(
        action(LogicalKeyboardKey.slash, shift: true),
        PlayerShortcut.help,
      );
      expect(action(LogicalKeyboardKey.period), isNull);
    });

    test('digits jump to 0% - 90%', () {
      expect(shortcutFor(LogicalKeyboardKey.digit0)?.percent, 0);
      expect(shortcutFor(LogicalKeyboardKey.digit7)?.percent, 70);
      expect(shortcutFor(LogicalKeyboardKey.numpad3)?.percent, 30);
    });

    test('speed steps stay inside the list', () {
      expect(stepSpeed(playbackSpeeds, 1, up: true), 1.25);
      expect(stepSpeed(playbackSpeeds, 1, up: false), 0.75);
      expect(stepSpeed(playbackSpeeds, 2, up: true), 2);
      expect(stepSpeed(playbackSpeeds, 0.25, up: false), 0.25);
    });
  });

  group('player settings are remembered', () {
    test('defaults: full volume, normal speed', () async {
      final container = await _container({});
      expect(container.read(playerVolumeProvider), 1.0);
      expect(container.read(playbackSpeedProvider), 1.0);
    });

    test('saved volume, speed and mute come back', () async {
      final container = await _container({
        'player_volume': 0.4,
        'player_speed': 1.5,
        'player_muted': true,
      });
      expect(container.read(playerVolumeProvider), 0.4);
      expect(container.read(playbackSpeedProvider), 1.5);
      expect(container.read(playerMutedProvider), isTrue);
      expect(container.read(effectiveVolumeProvider), 0);
    });

    test('changes are saved', () async {
      final container = await _container({});
      container.read(playerVolumeProvider.notifier).setVolume(0.3);
      container.read(playbackSpeedProvider.notifier).setSpeed(0.75);
      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getDouble('player_volume'), 0.3);
      expect(prefs.getDouble('player_speed'), 0.75);
      expect(container.read(effectiveVolumeProvider), 0.3);
    });

    test('out-of-range values are clamped', () async {
      final container = await _container({'player_speed': 9.0});
      expect(container.read(playbackSpeedProvider), 2.0);
      container.read(playerVolumeProvider.notifier).setVolume(3);
      expect(container.read(playerVolumeProvider), 1.0);
    });
  });

  test('report id and reasons match the rules', () {
    expect(reportId('sintel', 'u1'), 'sintel_u1');
    final rules = File('firestore.rules').readAsStringSync();
    for (final reason in reportReasons.keys) {
      expect(rules, contains("'$reason'"));
    }
    expect(rules, contains('match /reports/{reportId}'));
  });
}

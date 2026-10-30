import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// What a key does on the watch page (like YouTube's shortcuts).
enum PlayerShortcut {
  playPause,
  back10,
  forward10,
  back5,
  forward5,
  volumeUp,
  volumeDown,
  mute,
  fullscreen,
  exitOrMinimize,
  miniPlayer,
  next,
  previous,
  faster,
  slower,
  toStart,
  toEnd,
  seekPercent,
  help,
}

/// A shortcut, and for [PlayerShortcut.seekPercent] where to go (0..90).
typedef ShortcutCommand = ({PlayerShortcut action, int percent});

/// The command for [key] ([shift] = Shift is held), or null if the key
/// isn't a shortcut. Characters like ">" arrive either as their own key or
/// as Shift + the key under them, depending on the keyboard.
ShortcutCommand? shortcutFor(LogicalKeyboardKey key, {bool shift = false}) {
  ShortcutCommand c(PlayerShortcut action, [int percent = 0]) =>
      (action: action, percent: percent);

  if (key == LogicalKeyboardKey.greater ||
      (shift && key == LogicalKeyboardKey.period)) {
    return c(PlayerShortcut.faster);
  }
  if (key == LogicalKeyboardKey.less ||
      (shift && key == LogicalKeyboardKey.comma)) {
    return c(PlayerShortcut.slower);
  }
  if (key == LogicalKeyboardKey.question ||
      (shift && key == LogicalKeyboardKey.slash)) {
    return c(PlayerShortcut.help);
  }
  if (shift && key == LogicalKeyboardKey.keyN) return c(PlayerShortcut.next);
  if (shift && key == LogicalKeyboardKey.keyP) {
    return c(PlayerShortcut.previous);
  }

  final digit = _digits.indexOf(key);
  if (digit >= 0) return c(PlayerShortcut.seekPercent, (digit % 10) * 10);

  return switch (key) {
    LogicalKeyboardKey.space ||
    LogicalKeyboardKey.keyK => c(PlayerShortcut.playPause),
    LogicalKeyboardKey.keyJ => c(PlayerShortcut.back10),
    LogicalKeyboardKey.keyL => c(PlayerShortcut.forward10),
    LogicalKeyboardKey.arrowLeft => c(PlayerShortcut.back5),
    LogicalKeyboardKey.arrowRight => c(PlayerShortcut.forward5),
    LogicalKeyboardKey.arrowUp => c(PlayerShortcut.volumeUp),
    LogicalKeyboardKey.arrowDown => c(PlayerShortcut.volumeDown),
    LogicalKeyboardKey.keyM => c(PlayerShortcut.mute),
    LogicalKeyboardKey.keyF => c(PlayerShortcut.fullscreen),
    LogicalKeyboardKey.escape => c(PlayerShortcut.exitOrMinimize),
    LogicalKeyboardKey.keyI => c(PlayerShortcut.miniPlayer),
    LogicalKeyboardKey.home => c(PlayerShortcut.toStart),
    LogicalKeyboardKey.end => c(PlayerShortcut.toEnd),
    _ => null,
  };
}

const _digits = [
  LogicalKeyboardKey.digit0,
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
  LogicalKeyboardKey.digit8,
  LogicalKeyboardKey.digit9,
  LogicalKeyboardKey.numpad0,
  LogicalKeyboardKey.numpad1,
  LogicalKeyboardKey.numpad2,
  LogicalKeyboardKey.numpad3,
  LogicalKeyboardKey.numpad4,
  LogicalKeyboardKey.numpad5,
  LogicalKeyboardKey.numpad6,
  LogicalKeyboardKey.numpad7,
  LogicalKeyboardKey.numpad8,
  LogicalKeyboardKey.numpad9,
];

/// The next speed up (or down) in [speeds], staying at the ends.
double stepSpeed(List<double> speeds, double current, {required bool up}) {
  final index = speeds.indexWhere((s) => s >= current - 0.001);
  final at = index < 0 ? speeds.length - 1 : index;
  final next = (up ? at + 1 : at - 1).clamp(0, speeds.length - 1);
  return speeds[next];
}

/// Someone is typing (a comment, a search...): keys must go to the text.
bool isTypingInTextField() {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  return focused.widget is EditableText ||
      focused.findAncestorWidgetOfExactType<EditableText>() != null;
}

/// The "?" help list.
const List<(String, String)> shortcutHelp = [
  ('Space / K', 'Play or pause'),
  ('J / L', 'Back / forward 10 seconds'),
  ('← / →', 'Back / forward 5 seconds'),
  ('↑ / ↓', 'Volume up / down'),
  ('M', 'Mute or unmute'),
  ('F', 'Full screen'),
  ('Esc', 'Leave full screen / mini player'),
  ('I', 'Mini player'),
  ('Shift + N / P', 'Next / previous video'),
  ('> / <', 'Faster / slower'),
  ('0 - 9', 'Jump to 0% - 90%'),
  ('Home / End', 'Start / end'),
  ('?', 'Show these shortcuts'),
];

Future<void> showShortcutHelp(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Keyboard shortcuts'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (keys, what) in shortcutHelp)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          keys,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Expanded(child: Text(what)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

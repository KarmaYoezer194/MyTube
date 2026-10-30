import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../playback_controller.dart';

const List<double> playbackSpeeds = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2];

/// "1.5x", "0.25x", or "Normal" for 1.
String speedLabel(double speed) {
  if (speed == 1) return 'Normal';
  final text = speed == speed.roundToDouble()
      ? speed.toInt().toString()
      : speed.toString();
  return '${text}x';
}

/// Opened from the ⚙ button on the player.
Future<void> showPlaybackSpeedSheet(BuildContext context, WidgetRef ref) {
  final current = ref.read(playbackSpeedProvider);
  final speed = ref.read(playbackSpeedProvider.notifier);

  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Volume (remembered, like mute and speed) ----
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Text(
                'Volume',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            Consumer(
              builder: (context, ref, _) {
                final volume = ref.watch(playerVolumeProvider);
                final muted = ref.watch(playerMutedProvider);
                return Row(
                  children: [
                    IconButton(
                      tooltip: muted ? 'Unmute' : 'Mute',
                      onPressed: () => ref
                          .read(playerMutedProvider.notifier)
                          .setMuted(!muted),
                      icon: Icon(
                        muted || volume == 0
                            ? Symbols.volume_off
                            : Symbols.volume_up,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: muted ? 0 : volume,
                        label: '${((muted ? 0 : volume) * 100).round()}%',
                        divisions: 20,
                        onChanged: (value) {
                          ref
                              .read(playerVolumeProvider.notifier)
                              .setVolume(value);
                          if (muted && value > 0) {
                            ref
                                .read(playerMutedProvider.notifier)
                                .setMuted(false);
                          }
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Playback speed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            for (final option in playbackSpeeds)
              ListTile(
                dense: true,
                leading: option == current
                    ? const Icon(Symbols.check)
                    : const SizedBox(width: 24),
                title: Text(
                  speedLabel(option),
                  style: const TextStyle(fontSize: 15),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  speed.setSpeed(option);
                },
              ),
          ],
        ),
      ),
    ),
  );
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';

/// YouTube's progress bar: red for the part you watched, light grey for the
/// part already downloaded (buffered), dark grey for the rest, and a red
/// dot (scrubber) you can drag.
///
/// With [interactive] = false it's just a thin red line (used when the
/// controls are hidden, and in the mini player).
class PlayerProgressBar extends StatefulWidget {
  const PlayerProgressBar({
    super.key,
    required this.controller,
    this.interactive = true,
    this.thinUntilDragged = false,
    this.onInteraction,
  });

  final VideoPlayerController controller;
  final bool interactive;

  /// Shorts style: looks like the thin line, but you can still drag it.
  /// While dragging it gets thicker and shows the red dot.
  final bool thinUntilDragged;

  /// Called while you drag, so the controls don't hide in the middle.
  final VoidCallback? onInteraction;

  @override
  State<PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends State<PlayerProgressBar> {
  /// Where your finger is (0..1) while dragging, otherwise null.
  double? _dragFraction;

  void _dragTo(double dx, double width) {
    setState(() => _dragFraction = (dx / width).clamp(0.0, 1.0));
    widget.onInteraction?.call();
  }

  void _commit() {
    final fraction = _dragFraction;
    if (fraction == null) return;
    final total = widget.controller.value.duration;
    widget.controller.seekTo(total * fraction);
    setState(() => _dragFraction = null);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final total = value.duration.inMilliseconds;
        final played = total == 0
            ? 0.0
            : (value.position.inMilliseconds / total).clamp(0.0, 1.0);
        final bufferedEnd = value.buffered.fold<int>(
          0,
          (furthest, range) => math.max(furthest, range.end.inMilliseconds),
        );
        final buffered = total == 0
            ? 0.0
            : (bufferedEnd / total).clamp(0.0, 1.0);

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final bar = CustomPaint(
              size: Size(width, constraints.maxHeight),
              painter: _ProgressPainter(
                played: _dragFraction ?? played,
                buffered: buffered,
                thin:
                    !widget.interactive ||
                    (widget.thinUntilDragged && _dragFraction == null),
                dragging: _dragFraction != null,
              ),
            );
            if (!widget.interactive) return bar;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _dragTo(d.localPosition.dx, width),
              onTapUp: (_) => _commit(),
              onHorizontalDragStart: (d) => _dragTo(d.localPosition.dx, width),
              onHorizontalDragUpdate: (d) => _dragTo(d.localPosition.dx, width),
              onHorizontalDragEnd: (_) => _commit(),
              child: bar,
            );
          },
        );
      },
    );
  }
}

class _ProgressPainter extends CustomPainter {
  _ProgressPainter({
    required this.played,
    required this.buffered,
    required this.thin,
    required this.dragging,
  });

  final double played;
  final double buffered;

  /// Thin = a 2px line along the bottom, no dot.
  final bool thin;
  final bool dragging;

  @override
  void paint(Canvas canvas, Size size) {
    // The normal bar sits a little above the bottom edge so the whole dot
    // is visible; the thin line hugs the bottom edge.
    final y = thin ? size.height - 1 : size.height - 7;
    final thickness = thin ? 2.0 : (dragging ? 4.0 : 3.0);

    void line(double fraction, Color color) {
      canvas.drawRect(
        Rect.fromLTWH(0, y - thickness / 2, size.width * fraction, thickness),
        Paint()..color = color,
      );
    }

    line(1, Colors.white24);
    line(buffered, Colors.white54);
    line(played, AppColors.brandRed);

    if (!thin) {
      canvas.drawCircle(
        Offset(size.width * played, y),
        dragging ? 8 : 6,
        Paint()..color = AppColors.brandRed,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressPainter old) =>
      old.played != played ||
      old.buffered != buffered ||
      old.dragging != dragging ||
      old.thin != thin;
}

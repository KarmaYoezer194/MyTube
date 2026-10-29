import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum SeekSide { back, forward }

/// The "10 seconds" bubble that appears when you double-tap the left
/// (back) or right (forward) side of the player.
///
/// Every time [pulse] changes, a new ripple ring grows from the middle.
/// [seconds] adds up if you keep double-tapping (10, 20, 30...).
class SeekRipple extends StatelessWidget {
  const SeekRipple({
    super.key,
    required this.side,
    required this.seconds,
    required this.pulse,
  });

  final SeekSide side;
  final int seconds;
  final int pulse;

  @override
  Widget build(BuildContext context) {
    final forward = side == SeekSide.forward;

    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        return Stack(
          children: [
            // Big oval on one side, partly outside the player (clipped),
            // so it looks like YouTube's curved highlight.
            Positioned(
              top: -h * 0.25,
              bottom: -h * 0.25,
              left: forward ? w * 0.55 : -w * 0.3,
              width: w * 0.75,
              child: ClipOval(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: Color(0x1FFFFFFF)),
                    TweenAnimationBuilder<double>(
                      key: ValueKey(pulse),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOut,
                      builder: (context, t, _) => Center(
                        child: Opacity(
                          opacity: (1 - t) * 0.35,
                          child: Transform.scale(
                            scale: 0.2 + t * 1.4,
                            child: Container(
                              width: h,
                              height: h,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Arrows + "10 seconds"
            Positioned(
              top: 0,
              bottom: 0,
              left: forward ? w * 0.6 : 0,
              width: w * 0.4,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.flip(
                    flipX: !forward,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Symbols.play_arrow,
                            fill: 1, color: Colors.white70, size: 18),
                        Icon(Symbols.play_arrow,
                            fill: 1, color: Colors.white, size: 18),
                        Icon(Symbols.play_arrow,
                            fill: 1, color: Colors.white70, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$seconds seconds',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

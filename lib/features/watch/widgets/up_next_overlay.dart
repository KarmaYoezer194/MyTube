import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../data/models/video.dart';

/// Shown over the player when a video ends and autoplay is on:
/// "Up next" + the next title + a ring that fills up in 5 seconds.
/// When the ring is full (or you tap it), the next video starts.
class UpNextOverlay extends StatefulWidget {
  const UpNextOverlay({
    super.key,
    required this.next,
    required this.onPlayNow,
    required this.onCancel,
  });

  final Video next;
  final VoidCallback onPlayNow;
  final VoidCallback onCancel;

  @override
  State<UpNextOverlay> createState() => _UpNextOverlayState();
}

class _UpNextOverlayState extends State<UpNextOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _countdown = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onPlayNow();
    })
    ..forward();

  @override
  void dispose() {
    _countdown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xCC000000),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _countdown,
                builder: (context, _) {
                  final left = (5 - _countdown.value * 5).ceil();
                  return Text(
                    'Up next in $left',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  );
                },
              ),
              const SizedBox(height: 4),
              Text(
                widget.next.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: widget.onPlayNow,
                child: SizedBox.square(
                  dimension: 56,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AnimatedBuilder(
                        animation: _countdown,
                        builder: (context, _) => CircularProgressIndicator(
                          value: _countdown.value,
                          strokeWidth: 3,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      const Icon(Symbols.play_arrow,
                          fill: 1, color: Colors.white, size: 32),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.onCancel,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

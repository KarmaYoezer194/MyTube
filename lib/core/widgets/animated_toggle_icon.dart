import 'package:flutter/material.dart';

/// An icon that is outlined when off and filled when on. When it turns on
/// it does a little "bounce" (grows, shrinks a bit, settles).
/// Used for like / dislike / save on the watch page and in Shorts.
class AnimatedToggleIcon extends StatefulWidget {
  const AnimatedToggleIcon({
    super.key,
    required this.icon,
    required this.active,
    this.size = 20,
    this.color,
  });

  final IconData icon;
  final bool active;
  final double size;
  final Color? color;

  @override
  State<AnimatedToggleIcon> createState() => _AnimatedToggleIconState();
}

class _AnimatedToggleIconState extends State<AnimatedToggleIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  // 1.0 -> 1.4 -> 0.9 -> 1.0
  late final Animation<double> _scale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 1.4, end: 0.9), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 30),
  ]).animate(CurvedAnimation(parent: _bounce, curve: Curves.easeOut));

  @override
  void didUpdateWidget(AnimatedToggleIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) _bounce.forward(from: 0);
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: widget.active ? 1 : 0),
        duration: const Duration(milliseconds: 200),
        builder: (context, fill, _) => Icon(
          widget.icon,
          size: widget.size,
          fill: fill,
          color: widget.color ?? IconTheme.of(context).color,
        ),
      ),
    );
  }
}

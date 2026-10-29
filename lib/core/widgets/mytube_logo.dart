import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The MyTube logo: a red circle with a white play triangle, then the word
/// "MyTube". Drawn with plain Flutter shapes, no image file needed.
class MyTubeLogo extends StatelessWidget {
  const MyTubeLogo({super.key, this.size = 24});

  /// Height of the red circle. The text scales with it.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MyTubeLogoMark(size: size),
        SizedBox(width: size * 0.2),
        Text(
          'MyTube',
          style: TextStyle(
            fontSize: size * 0.9,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            height: 1,
            color: context.colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Just the red circle with the play triangle (no text).
class MyTubeLogoMark extends StatelessWidget {
  const MyTubeLogoMark({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.brandRed,
        shape: BoxShape.circle,
      ),
      // Nudge the triangle right a little so it looks centered to the eye.
      padding: EdgeInsets.only(left: size * 0.08),
      alignment: Alignment.center,
      child: CustomPaint(
        size: Size(size * 0.38, size * 0.44),
        painter: _PlayTrianglePainter(),
      ),
    );
  }
}

class _PlayTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

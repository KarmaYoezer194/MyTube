import 'package:flutter/material.dart';

import 'network_thumbnail.dart';

/// Round channel / user picture.
///
/// If there is no picture, shows the first letter of the name on a colored
/// circle (like new YouTube accounts). The same name always gets the same
/// color.
class ChannelAvatar extends StatelessWidget {
  const ChannelAvatar({
    super.key,
    required this.name,
    this.imageUrl = '',
    this.size = 36,
  });

  final String name;
  final String imageUrl;
  final double size;

  static const _palette = [
    Color(0xFFD81B60),
    Color(0xFF8E24AA),
    Color(0xFF5E35B1),
    Color(0xFF3949AB),
    Color(0xFF0277BD),
    Color(0xFF00897B),
    Color(0xFF558B2F),
    Color(0xFFEF6C00),
    Color(0xFF6D4C41),
    Color(0xFF546E7A),
  ];

  Color get _color {
    // Add up the character codes: simple and always the same for a name.
    final sum = name.codeUnits.fold<int>(0, (total, unit) => total + unit);
    return _palette[sum % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isNotEmpty) {
      return ClipOval(
        child: SizedBox.square(
          dimension: size,
          child: NetworkThumbnail(url: imageUrl),
        ),
      );
    }

    final trimmed = name.trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
      child: Text(
        trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.45,
          fontWeight: FontWeight.w500,
          height: 1,
        ),
      ),
    );
  }
}

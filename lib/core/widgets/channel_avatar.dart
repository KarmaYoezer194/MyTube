import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/avatar_colors.dart';
import 'network_thumbnail.dart';

/// A saved color number (like 0xFFD81B60) as a [Color], or null.
Color? avatarColorOrNull(int? value) => value == null ? null : Color(value);

/// Round channel / user picture.
///
/// - Has a picture: shows it.
/// - Has a name: the first letter on a colored circle (like new YouTube
///   accounts). The color is [color] if given (a user's saved avatarColor),
///   otherwise it comes from the name, so it is always the same.
/// - No name (a guest): a grey circle with a person icon.
class ChannelAvatar extends StatelessWidget {
  const ChannelAvatar({
    super.key,
    required this.name,
    this.imageUrl = '',
    this.size = 36,
    this.color,
  });

  final String name;
  final String imageUrl;
  final double size;
  final Color? color;

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
    if (trimmed.isEmpty) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.colors.surface,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Symbols.person,
          fill: 1,
          size: size * 0.6,
          color: context.colors.textSecondary,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color ?? avatarColorFor(trimmed),
        shape: BoxShape.circle,
      ),
      child: Text(
        trimmed.characters.first.toUpperCase(),
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

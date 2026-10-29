import 'package:flutter/material.dart';

/// Colors for letter avatars (the colored circle with your first letter).
const List<Color> avatarPalette = [
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

/// The avatar color for a name. The same name always gets the same color,
/// so your avatar looks the same on your profile, comments and videos.
Color avatarColorFor(String name) {
  // Add up the character codes: simple and always the same for a name.
  final sum = name.codeUnits.fold<int>(0, (total, unit) => total + unit);
  return avatarPalette[sum % avatarPalette.length];
}

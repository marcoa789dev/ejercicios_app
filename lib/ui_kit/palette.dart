import 'package:flutter/material.dart';

/// Colores fijos para categorías e integrantes (se guardan como `#RRGGBB`).
const kPaletteHex = [
  '#2E7D6B',
  '#1E88E5',
  '#7E57C2',
  '#D81B60',
  '#F4511E',
  '#F9A825',
  '#43A047',
  '#6D4C41',
  '#546E7A',
];

Color colorFromHex(String? hex, {Color fallback = const Color(0xFF2E7D6B)}) {
  final v = int.tryParse((hex ?? '').replaceFirst('#', ''), radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}

/// Íconos de categoría: clave guardada en Firestore → ícono.
const kCategoryIcons = <String, IconData>{
  'knee': Icons.accessibility_new_rounded,
  'shoulder': Icons.sports_gymnastics_rounded,
  'neck': Icons.self_improvement_rounded,
  'back': Icons.airline_seat_flat_rounded,
  'walk': Icons.directions_walk_rounded,
  'strength': Icons.fitness_center_rounded,
  'heart': Icons.favorite_rounded,
  'stretch': Icons.sports_martial_arts_rounded,
};

IconData categoryIcon(String? key) =>
    kCategoryIcons[key] ?? Icons.fitness_center_rounded;

/// Avatares de integrantes: clave guardada en Firestore → ícono.
const kAvatars = <String, IconData>{
  'person': Icons.person_rounded,
  'face': Icons.face_rounded,
  'flower': Icons.local_florist_rounded,
  'star': Icons.star_rounded,
  'sun': Icons.wb_sunny_rounded,
  'pet': Icons.pets_rounded,
  'music': Icons.music_note_rounded,
  'sports': Icons.sports_soccer_rounded,
  'coffee': Icons.coffee_rounded,
};

IconData avatarIcon(String? key) => kAvatars[key] ?? Icons.person_rounded;

/// Círculo con el avatar y el color de un integrante.
class MemberAvatar extends StatelessWidget {
  const new({
    required this.colorHex,
    required this.avatar,
    this.radius = 20,
    super.key,
  });

  final String colorHex;
  final String avatar;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: colorFromHex(colorHex),
    foregroundColor: Colors.white,
    child: Icon(avatarIcon(avatar), size: radius),
  );
}

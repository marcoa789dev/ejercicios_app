import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const seed = Color(0xFF2E7D6B);

  static ThemeData light() =>
      ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: seed));

  static ThemeData dark() => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ),
  );
}

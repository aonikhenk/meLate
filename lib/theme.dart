import 'package:flutter/material.dart';

class MeColors {
  static const cream = Color(0xFFFFF7F0);
  static const coral = Color(0xFFF2675A);
  static const plum = Color(0xFF7D6B9E);
  static const ink = Color(0xFF3B2F2F);
  static const soft = Color(0xFF8A7B76);
}

ThemeData melateTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
        seedColor: MeColors.coral, surface: MeColors.cream),
    scaffoldBackgroundColor: MeColors.cream,
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineMedium: const TextStyle(
          fontSize: 30, fontWeight: FontWeight.w800, color: MeColors.coral),
      displaySmall: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: MeColors.ink,
          height: 1.25),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: MeColors.cream,
      foregroundColor: MeColors.ink,
      elevation: 0,
      titleTextStyle: TextStyle(
          fontSize: 26, fontWeight: FontWeight.w700, color: MeColors.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(fontSize: 20, color: MeColors.soft),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    ),
  );
}

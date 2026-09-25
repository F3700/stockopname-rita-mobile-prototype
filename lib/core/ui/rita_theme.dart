import 'package:flutter/material.dart';

import 'design_system/rita_tokens.dart';

ThemeData ritaTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: RitaPalette.primary);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: RitaPalette.background,
    appBarTheme: const AppBarTheme(centerTitle: true),
    dialogTheme: DialogThemeData(
      backgroundColor: RitaPalette.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RitaRadius.lg),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: RitaPalette.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(RitaSizes.button),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RitaRadius.md),
        ),
      ),
    ),
  );
}

/// Format rupiah sederhana tanpa dependensi baru.
String rupiah(num value) {
  final s = value.toStringAsFixed(0);
  final buf = StringBuffer();
  var count = 0;
  for (var i = s.length - 1; i >= 0; i--) {
    buf.write(s[i]);
    count++;
    if (count == 3 && i != 0) {
      buf.write('.');
      count = 0;
    }
  }
  return buf.toString().split('').reversed.join();
}

import 'package:flutter/material.dart';

/// Token visual Rita v5 — satu sumber kebenaran untuk warna, radius,
/// spacing, ukuran, dan tipografi. Dipakai semua komponen design system.
/// Padanan token Penpot: set `rita/global` (lihat DESIGN.md).
class RitaPalette {
  const RitaPalette._();

  static const primary = Color(0xFFC00000);
  static const pressed = Color(0xFF9A0000);
  static const ink = Color(0xFF1A1A1A);
  static const grey = Color(0xFF5F6368);
  static const hint = Color(0xFF6B7280);
  static const label = Color(0xFF616161);
  static const border = Color(0xFFD9D9D9);
  static const line = Color(0xFFE3E3E3);
  static const track = Color(0xFFEDEDED);
  static const neutral = Color(0xFFF1F3F4);
  static const background = Color(0xFFF6F6F6);
  static const white = Colors.white;

  static const success = Color(0xFF1B9E4B);
  static const successBg = Color(0xFFE5F4EB);

  /// Hijau untuk TEKS (kontras >= 4.5:1 di atas [successBg]/putih).
  static const successText = Color(0xFF157A3E);

  static const warning = Color(0xFFE8890B);
  static const warningBg = Color(0xFFFCEEDD);

  /// Amber untuk TEKS (kontras >= 4.5:1 di atas [warningBg]/putih).
  static const warningText = Color(0xFF9A5000);

  static const primarySurface = Color(0xFFFDECEC);
  static const error = primary;
  static const focus = Color(0xFF1A73E8);
  static const toast = Color(0xFF323232);
}

class RitaRadius {
  const RitaRadius._();

  static const sm = 10.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const pill = 12.0;
  static const circle = 999.0;
}

class RitaSpace {
  const RitaSpace._();

  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;

  /// Margin layar standar (grid 16).
  static const screen = 16.0;
}

class RitaSizes {
  const RitaSizes._();

  static const band = 80.0;
  static const button = 56.0;
  static const field = 52.0;
  static const pill = 24.0;
  static const iconTarget = 44.0;
  static const iconGlyph = 24.0;
  static const fab = 56.0;
}

/// Skala tipografi v5 (Inter mengikuti theme default platform).
class RitaType {
  const RitaType._();

  static const display = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: RitaPalette.ink,
  );
  static const title = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: RitaPalette.ink,
  );
  static const cardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: RitaPalette.ink,
  );
  static const body = TextStyle(fontSize: 16, color: RitaPalette.ink);
  static const body15 = TextStyle(fontSize: 15, color: RitaPalette.ink);
  static const strong15 = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: RitaPalette.ink,
  );
  static const meta = TextStyle(fontSize: 13, color: RitaPalette.grey);
  static const caption = TextStyle(fontSize: 12, color: RitaPalette.grey);
  static const hint = TextStyle(fontSize: 14, color: RitaPalette.hint);
  static const captionHint = TextStyle(fontSize: 12, color: RitaPalette.hint);
  static const data = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: RitaPalette.primary,
  );
  static const pill = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );
  static const button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );
  static const fieldLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: RitaPalette.label,
  );
  static const sectionLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: RitaPalette.grey,
  );
}

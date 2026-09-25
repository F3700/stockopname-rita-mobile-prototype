import 'package:flutter/material.dart';

import 'rita_tokens.dart';

/// Status sesi/koordinator/rak versi v5.
enum RitaStatus { berjalan, selesai, proses, belumUpload, gagal }

/// Pill status v5: tinggi 24, radius 12, padding horizontal 10,
/// label 11/700. Warna = semantik, bukan dekorasi.
class RitaPill extends StatelessWidget {
  const RitaPill({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
    this.border,
  });

  /// Konstruktor semantik dari [RitaStatus].
  factory RitaPill.status(RitaStatus status) {
    switch (status) {
      case RitaStatus.berjalan:
        return const RitaPill(
          label: 'Berjalan',
          bg: RitaPalette.primarySurface,
          fg: RitaPalette.primary,
        );
      case RitaStatus.selesai:
        return const RitaPill(
          label: 'Selesai',
          bg: RitaPalette.successBg,
          fg: RitaPalette.successText,
        );
      case RitaStatus.proses:
        return const RitaPill(
          label: 'Proses',
          bg: RitaPalette.neutral,
          fg: RitaPalette.grey,
          border: RitaPalette.border,
        );
      case RitaStatus.belumUpload:
        return const RitaPill(
          label: 'Belum upload',
          bg: RitaPalette.warningBg,
          fg: RitaPalette.warningText,
        );
      case RitaStatus.gagal:
        return const RitaPill(
          label: 'Gagal',
          bg: RitaPalette.primarySurface,
          fg: RitaPalette.primary,
        );
    }
  }

  /// Tag di atas putih (mis. "via QR", "HASIL SCAN").
  factory RitaPill.tag(
    String label, {
    Color bg = RitaPalette.white,
    Color fg = RitaPalette.grey,
    Color? border = RitaPalette.border,
  }) => RitaPill(label: label, bg: bg, fg: fg, border: border);

  final String label;
  final Color bg;
  final Color fg;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: RitaSizes.pill,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(RitaRadius.pill),
        border: border == null ? null : Border.all(color: border!),
      ),
      alignment: Alignment.center,
      child: Text(label, style: RitaType.pill.copyWith(color: fg), maxLines: 1),
    );
  }
}

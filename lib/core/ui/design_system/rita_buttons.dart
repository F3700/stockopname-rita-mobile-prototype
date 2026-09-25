import 'package:flutter/material.dart';

import 'rita_tokens.dart';

/// Tombol utama v5: tinggi 56, radius 12, merah, label 15/700.
/// `loading` menampilkan spinner kecil dan menonaktifkan tap.
class RitaPrimaryButton extends StatelessWidget {
  const RitaPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: RitaSizes.button,
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: RitaPalette.primary,
          disabledBackgroundColor: RitaPalette.primary.withValues(alpha: 0.6),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RitaRadius.md),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label, style: RitaType.button),
      ),
    );
  }
}

/// Tombol sekunder v5: putih, border merah 1.5, label merah, tinggi 56.
class RitaSecondaryButton extends StatelessWidget {
  const RitaSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: RitaSizes.button,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: RitaPalette.primary,
          side: const BorderSide(color: RitaPalette.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RitaRadius.md),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: RitaSizes.iconGlyph, color: RitaPalette.primary),
              const SizedBox(width: RitaSpace.xs),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RitaType.button.copyWith(color: RitaPalette.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tombol ikon v5: target 44x44, glyph 24 center, opsional scrim gelap
/// (dipakai di atas kamera).
class RitaIconButton extends StatelessWidget {
  const RitaIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color = RitaPalette.ink,
    this.scrim = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;
  final bool scrim;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: RitaSizes.iconTarget,
      height: RitaSizes.iconTarget,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        iconSize: RitaSizes.iconGlyph,
        style: scrim
            ? IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.55),
              )
            : null,
        icon: Icon(icon, color: color),
      ),
    );
  }
}

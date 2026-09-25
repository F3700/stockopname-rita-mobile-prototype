import 'package:flutter/material.dart';

import 'rita_tokens.dart';

/// Band merah compact 80px (v5) — pengganti AppBar untuk layar ber-brand.
///
/// Anatomi: title 20/700 di atas, sub 12/400 (opsional, bisa dengan dot
/// status), tombol back 44x44 di kiri, dan slot kanan (pill status/avatar)
/// yang selalu center vertikal.
class RitaBand extends StatelessWidget implements PreferredSizeWidget {
  const RitaBand({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.subtitleDot,
    this.subtitleColor,
  });

  final String title;
  final String? subtitle;

  /// Bila non-null, tombol back 44x44 tampil (24px glyph, center).
  final VoidCallback? onBack;

  /// Slot kanan: pill status, avatar, atau kosong.
  final Widget? trailing;

  /// Warna dot 8px sebelum subtitle (mis. hijau online / amber offline).
  final Color? subtitleDot;
  final Color? subtitleColor;

  @override
  Size get preferredSize => const Size.fromHeight(RitaSizes.band);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: RitaSizes.band,
      backgroundColor: RitaPalette.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      leadingWidth: onBack == null ? 0 : 56,
      leading: onBack == null
          ? null
          : Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: SizedBox(
                  width: RitaSizes.iconTarget,
                  height: RitaSizes.iconTarget,
                  child: IconButton(
                    onPressed: onBack,
                    iconSize: RitaSizes.iconGlyph,
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Kembali',
                  ),
                ),
              ),
            ),
      titleSpacing: 0,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: RitaType.display.copyWith(color: Colors.white)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (subtitleDot != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: subtitleDot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RitaType.caption.copyWith(
                      color: subtitleColor ?? Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: trailing == null
          ? null
          : [
              Padding(
                padding: const EdgeInsets.only(right: RitaSpace.screen),
                child: Center(child: trailing),
              ),
            ],
    );
  }
}

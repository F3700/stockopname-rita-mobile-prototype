import 'package:flutter/material.dart';

import 'rita_tokens.dart';

/// Jenis banner keadaan v5.
enum RitaBannerKind { offline, syncing, error, success, info }

/// Banner inline v5: radius 12, dot/ikon status, judul 14/700, sub 12,
/// aksi teks opsional. Tinggi mengikuti konten (padding 12x16).
class RitaBanner extends StatelessWidget {
  const RitaBanner({
    super.key,
    required this.title,
    this.message,
    this.kind = RitaBannerKind.info,
    this.actionLabel,
    this.onAction,
    this.progress,
  });

  final String title;
  final String? message;
  final RitaBannerKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 0..1 — hanya dipakai varian [RitaBannerKind.syncing].
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final (bg, accent) = switch (kind) {
      RitaBannerKind.offline => (RitaPalette.warningBg, RitaPalette.warning),
      RitaBannerKind.syncing => (RitaPalette.neutral, RitaPalette.grey),
      RitaBannerKind.error => (RitaPalette.primarySurface, RitaPalette.error),
      RitaBannerKind.success => (RitaPalette.successBg, RitaPalette.success),
      RitaBannerKind.info => (RitaPalette.neutral, RitaPalette.grey),
    };
    final icon = switch (kind) {
      RitaBannerKind.offline => Icons.wifi_off,
      RitaBannerKind.syncing => Icons.sync,
      RitaBannerKind.error => Icons.error_outline,
      RitaBannerKind.success => Icons.check_circle_outline,
      RitaBannerKind.info => Icons.info_outline,
    };
    return Container(
      padding: const EdgeInsets.all(RitaSpace.sm),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(RitaRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: RitaSpace.xs + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: RitaType.strong15.copyWith(fontSize: 14)),
                if (message != null) ...[
                  const SizedBox(height: 2),
                  Text(message!, style: RitaType.caption),
                ],
                if (progress != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: RitaPalette.track,
                      valueColor: const AlwaysStoppedAnimation(
                        RitaPalette.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: RitaPalette.primary,
                padding: const EdgeInsets.symmetric(horizontal: RitaSpace.xs),
                minimumSize: const Size(48, 32),
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Toast v5: snackbar gelap radius 12, opsional ikon check dan aksi
/// ("Ulangi"). Satu pesan menggantikan yang sedang tampil (anti menumpuk).
void showRitaToast(
  BuildContext context,
  String message, {
  bool success = false,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: RitaPalette.toast,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(RitaSpace.screen),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RitaRadius.md),
      ),
      duration: const Duration(seconds: 3),
      content: Row(
        children: [
          if (success) ...[
            const Icon(Icons.check, size: 20, color: RitaPalette.success),
            const SizedBox(width: RitaSpace.xs),
          ],
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
          ),
        ],
      ),
      action: actionLabel == null
          ? null
          : SnackBarAction(
              label: actionLabel,
              textColor: Colors.white,
              onPressed: onAction ?? () {},
            ),
    ),
  );
}

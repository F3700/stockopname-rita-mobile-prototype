import 'package:flutter/material.dart';

import 'rita_buttons.dart';
import 'rita_card.dart';
import 'rita_tokens.dart';

/// Empty state v5: kartu putih dengan ikon lingkaran, judul 16/700,
/// pesan 13, aksi opsional. Mengajari layar, bukan sekadar "kosong".
class RitaEmptyState extends StatelessWidget {
  const RitaEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.search,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return RitaCard(
      padding: const EdgeInsets.all(RitaSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: RitaPalette.background,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: RitaPalette.grey),
          ),
          const SizedBox(height: RitaSpace.sm),
          Text(title, style: RitaType.cardTitle, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(message, style: RitaType.meta, textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: RitaSpace.md),
            SizedBox(
              width: 200,
              child: RitaPrimaryButton(
                label: actionLabel!,
                onPressed: onAction,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Blok skeleton loading v5 (neutral, radius 12).
class RitaSkeleton extends StatelessWidget {
  const RitaSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 56,
    this.radius = RitaRadius.md,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: RitaPalette.neutral,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Deretan skeleton untuk daftar (mis. 3 kartu).
class RitaListSkeleton extends StatelessWidget {
  const RitaListSkeleton({super.key, this.rows = 3, this.height = 72});

  final int rows;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows; i++) ...[
          if (i > 0) const SizedBox(height: RitaSpace.sm),
          RitaSkeleton(height: height),
        ],
      ],
    );
  }
}

/// Loading tengah layar dengan label opsional.
class RitaLoading extends StatelessWidget {
  const RitaLoading({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: RitaPalette.primary,
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: RitaSpace.sm),
            Text(label!, style: RitaType.caption),
          ],
        ],
      ),
    );
  }
}

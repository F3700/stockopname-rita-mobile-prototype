import 'package:flutter/material.dart';

import 'rita_tokens.dart';

/// Kartu v5: putih, radius 16, garis hairline `#E3E3E3`, TANPA shadow.
/// Padding dalam default 16.
class RitaCard extends StatelessWidget {
  const RitaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(RitaSpace.md),
    this.onTap,
    this.color = RitaPalette.white,
    this.borderColor = RitaPalette.line,
    this.radius = RitaRadius.lg,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      side: BorderSide(color: borderColor),
      borderRadius: BorderRadius.circular(radius),
    );
    return Material(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}

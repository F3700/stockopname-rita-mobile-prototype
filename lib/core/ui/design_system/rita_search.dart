import 'package:flutter/material.dart';

import 'rita_tokens.dart';

/// Search pill v5: tinggi 52, radius 26, ikon kaca pembesar 24 di kiri,
/// tombol bersihkan saat ada teks.
class RitaSearchField extends StatelessWidget {
  const RitaSearchField({
    super.key,
    required this.controller,
    this.hint = 'Cari...',
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: RitaPalette.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: RitaPalette.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(
            Icons.search,
            size: RitaSizes.iconGlyph,
            color: RitaPalette.grey,
          ),
          const SizedBox(width: RitaSpace.xs),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: RitaType.body15,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: RitaType.hint,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) => value.text.isEmpty
                ? const SizedBox(width: RitaSpace.sm)
                : SizedBox(
                    width: RitaSizes.iconTarget,
                    height: RitaSizes.iconTarget,
                    child: IconButton(
                      onPressed: () {
                        controller.clear();
                        onChanged?.call('');
                      },
                      tooltip: 'Bersihkan',
                      iconSize: 20,
                      icon: const Icon(Icons.close, color: RitaPalette.grey),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'rita_tokens.dart';

/// Input field v5: label kapital 12/700 di atas, kotak putih 52px radius 12,
/// hint 14. Varian: default / focus (ring biru) / error (ring merah + pesan)
/// / disabled (abu).
class RitaField extends StatelessWidget {
  const RitaField({
    super.key,
    required this.label,
    required this.controller,
    this.hint = '',
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.onSubmitted,
    this.errorText,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.textInputAction,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: RitaType.fieldLabel),
        const SizedBox(height: 6),
        SizedBox(
          height: RitaSizes.field,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            enabled: enabled,
            focusNode: focusNode,
            autofocus: autofocus,
            textInputAction: textInputAction,
            style: RitaType.body,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: RitaSpace.md,
              ),
              hintText: hint,
              hintStyle: RitaType.hint,
              filled: true,
              fillColor: enabled ? RitaPalette.white : RitaPalette.neutral,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(RitaRadius.md),
                borderSide: BorderSide(
                  color: hasError ? RitaPalette.error : RitaPalette.border,
                  width: hasError ? 2 : 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(RitaRadius.md),
                borderSide: BorderSide(
                  color: hasError ? RitaPalette.error : RitaPalette.focus,
                  width: 2,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(RitaRadius.md),
                borderSide: const BorderSide(color: RitaPalette.line),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(RitaRadius.md),
                borderSide: const BorderSide(
                  color: RitaPalette.error,
                  width: 2,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(RitaRadius.md),
                borderSide: const BorderSide(
                  color: RitaPalette.error,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: RitaType.caption.copyWith(color: RitaPalette.error),
          ),
        ],
      ],
    );
  }
}

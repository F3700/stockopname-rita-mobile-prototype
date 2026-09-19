import 'package:flutter/material.dart';

/// Identitas visual Rita — dipakai semua layar.
class RitaColors {
  const RitaColors._();

  static const red = Color(0xFFC00000);
  static const grey = Color(0xFF818181);
  static const lightGrey = Color(0xFF929292);
}

ThemeData ritaTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: RitaColors.red);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(centerTitle: true),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: RitaColors.red,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    ),
  );
}

/// Input kotak ala form Niko: judul + TextField + maxlength.
class RitaInput extends StatelessWidget {
  const RitaInput({
    super.key,
    required this.controller,
    required this.title,
    this.hint = '',
    this.maxLength = 100,
    this.keyboardType = TextInputType.text,
    this.required = true,
  });

  final TextEditingController controller;
  final String title;
  final String hint;
  final int maxLength;
  final TextInputType keyboardType;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.all(10),
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD9D9D9)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: title.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF616161),
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
              children: [
                if (required)
                  const TextSpan(
                    text: '*',
                    style: TextStyle(color: RitaColors.red),
                  ),
              ],
            ),
          ),
          TextField(
            controller: controller,
            maxLength: maxLength,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              labelText: hint,
              labelStyle:
                  const TextStyle(fontSize: 12, color: RitaColors.lightGrey),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: RitaColors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }
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

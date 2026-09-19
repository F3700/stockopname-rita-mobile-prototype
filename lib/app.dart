import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/ui/rita_theme.dart';
import 'features/home/home_screen.dart';

class RitaApp extends StatelessWidget {
  const RitaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Rita Stock Opname',
        theme: ritaTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}

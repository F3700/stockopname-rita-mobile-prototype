import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/session_repository.dart';
import '../../core/error/app_error.dart';
import '../../core/ui/design_system/rita_band.dart';
import '../../core/ui/design_system/rita_buttons.dart';
import '../../core/ui/design_system/rita_card.dart';
import '../../core/ui/design_system/rita_field.dart';
import '../../core/ui/design_system/rita_tokens.dart';
import '../../core/ui/rita_dialog.dart';
import '../catalog/sync_gate.dart';
import '../racks/rack_list_screen.dart';
import 'setup_service.dart';

/// Form mulai sesi (v5): kode sesi + koor + inspektor + rak satu-satu.
class SessionFormScreen extends ConsumerStatefulWidget {
  const SessionFormScreen({super.key});

  @override
  ConsumerState<SessionFormScreen> createState() => _SessionFormScreenState();
}

class _SessionFormScreenState extends ConsumerState<SessionFormScreen> {
  final sesiCtrl = TextEditingController();
  final coorCtrl = TextEditingController();
  final inspectorCtrl = TextEditingController();
  final rakCtrl = TextEditingController();
  final rakNames = <String>[];
  bool busy = false;
  String? error;

  @override
  void dispose() {
    sesiCtrl.dispose();
    coorCtrl.dispose();
    inspectorCtrl.dispose();
    rakCtrl.dispose();
    super.dispose();
  }

  void _addRak() {
    final name = rakCtrl.text.trim();
    if (name.isEmpty) return;
    if (rakNames.contains(name)) {
      setState(() => error = 'Rak $name sudah ada di daftar.');
      return;
    }
    setState(() {
      rakNames.add(name);
      error = null;
    });
    rakCtrl.clear();
  }

  Future<void> _submit() async {
    // Ambil container di awal — context tidak boleh dipakai setelah await.
    final container = ProviderScope.containerOf(context);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      // Gerbang: wajib online + master segar. Batal = tetap di form,
      // tidak ada sesi/inspector yang terbuat.
      final proceed = await ensureOnlineAndFresh(
        context,
        container,
        'Masuk sesi',
      );
      if (!proceed || !mounted) return;
      final session = await ref
          .read(setupServiceProvider)
          .setup(
            sesiCode: sesiCtrl.text.trim(),
            coorCode: coorCtrl.text.trim(),
            inspectorCode: inspectorCtrl.text.trim(),
            rakNames: List.of(rakNames),
          );
      ref.read(activeSessionProvider.notifier).set(session);
      ref.invalidate(sessionListProvider);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RackListScreen()),
      );
    } catch (e) {
      final msg = e is AppFailure ? e.userMessage : e.toString();
      if (mounted) setState(() => error = msg);
      if (mounted) {
        // Tetap tampilkan inline error + pop-up notifikasi agar jelas.
        await showRitaError(
          context: context,
          title: 'Gagal masuk sesi',
          message: msg,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RitaBand(
        title: 'Mulai sesi',
        subtitle: 'Kode sesi, koordinator, inspektur',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          RitaSpace.screen,
          RitaSpace.md,
          RitaSpace.screen,
          100,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RitaField(
              label: 'KODE SESI',
              controller: sesiCtrl,
              hint: 'contoh: SO-2026-01',
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: RitaSpace.md),
            RitaField(
              label: 'KODE KOORDINATOR',
              controller: coorCtrl,
              hint: 'contoh: KOOR1',
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: RitaSpace.md),
            RitaField(
              label: 'KODE INSPEKTOR',
              controller: inspectorCtrl,
              hint: 'contoh: INSPECTOR1',
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: RitaSpace.lg),
            Text(
              'RAK - ${rakNames.length} DITAMBAHKAN',
              style: RitaType.sectionLabel,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: RitaSizes.field,
                    child: TextField(
                      controller: rakCtrl,
                      keyboardType: TextInputType.number,
                      onSubmitted: (_) => _addRak(),
                      style: RitaType.body,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: RitaSpace.md,
                        ),
                        hintText: 'Nomor rak, mis. 1021',
                        hintStyle: RitaType.hint,
                        filled: true,
                        fillColor: RitaPalette.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(RitaRadius.md),
                          borderSide: const BorderSide(
                            color: RitaPalette.border,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(RitaRadius.md),
                          borderSide: const BorderSide(
                            color: RitaPalette.focus,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: RitaSpace.xs),
                SizedBox(
                  width: 94,
                  height: RitaSizes.field,
                  child: FilledButton(
                    onPressed: _addRak,
                    style: FilledButton.styleFrom(
                      backgroundColor: RitaPalette.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(RitaRadius.md),
                      ),
                    ),
                    child: const Text(
                      'Tambah',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (rakNames.isNotEmpty) ...[
              const SizedBox(height: RitaSpace.sm),
              for (var i = 0; i < rakNames.length; i++) ...[
                if (i > 0) const SizedBox(height: RitaSpace.xs),
                RitaCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: RitaSpace.md,
                    vertical: 2,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(rakNames[i], style: RitaType.cardTitle),
                      ),
                      RitaIconButton(
                        icon: Icons.delete_outline,
                        color: RitaPalette.primary,
                        tooltip: 'Hapus rak',
                        onPressed: () => setState(() => rakNames.removeAt(i)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            if (error != null) ...[
              const SizedBox(height: RitaSpace.sm),
              Text(
                error!,
                style: RitaType.caption.copyWith(color: RitaPalette.error),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(RitaSpace.screen),
          child: RitaPrimaryButton(
            label: 'LANJUT KE RAK',
            loading: busy,
            onPressed: busy ? null : _submit,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/session_repository.dart';
import '../../core/error/app_error.dart';
import '../../core/ui/rita_dialog.dart';
import '../../core/ui/rita_theme.dart';
import '../catalog/sync_gate.dart';
import '../racks/rack_list_screen.dart';
import 'setup_service.dart';

/// Form mulai sesi: kode sesi + koor + inspektor + rak satu-satu.
/// Tanpa barcode, tanpa lokasi.
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
      final proceed =
          await ensureOnlineAndFresh(context, container, 'Masuk sesi');
      if (!proceed || !mounted) return;
      final session = await ref.read(setupServiceProvider).setup(
            sesiCode: sesiCtrl.text.trim(),
            coorCode: coorCtrl.text.trim(),
            inspectorCode: inspectorCtrl.text.trim(),
            rakNames: List.of(rakNames),
          );
      ref.read(activeSessionProvider.notifier).set(session);
      ref.invalidate(sessionListProvider);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => const RackListScreen()));
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          children: [
            Text('Mulai Sesi',
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            Text('Masukan informasi untuk memulai sesi',
                style:
                    TextStyle(color: RitaColors.grey, fontSize: 12)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 50),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RitaInput(
              controller: sesiCtrl,
              title: 'Kode Sesi',
              hint: 'contoh : SO-2026-01',
              maxLength: 20,
              keyboardType: TextInputType.text,
            ),
            RitaInput(
              controller: coorCtrl,
              title: 'Kode Koordinator',
              hint: 'contoh : KOOR1',
              maxLength: 20,
              keyboardType: TextInputType.text,
            ),
            RitaInput(
              controller: inspectorCtrl,
              title: 'Kode Inspektor',
              hint: 'contoh : INSPECTOR1',
              maxLength: 20,
              keyboardType: TextInputType.text,
            ),
            Container(
              padding: const EdgeInsets.all(15),
              margin: const EdgeInsets.all(10),
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.black)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('RAK',
                      style: TextStyle(
                          color: Color(0xFF616161),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0)),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: rakCtrl,
                      maxLength: 10,
                      keyboardType: TextInputType.number,
                      onSubmitted: (_) => _addRak(),
                      decoration: InputDecoration(
                        labelText: 'contoh: 1021',
                        labelStyle: const TextStyle(
                            fontSize: 12, color: RitaColors.lightGrey),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: RitaColors.red),
                        ),
                        suffix: IconButton(
                          onPressed: _addRak,
                          icon: const Icon(Icons.add_circle,
                              color: RitaColors.red),
                        ),
                      ),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rakNames.length,
              itemBuilder: (_, i) => Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.black),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 17),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(rakNames[i],
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            color: RitaColors.red, size: 28),
                        onPressed: () =>
                            setState(() => rakNames.removeAt(i)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(error!,
                    style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FilledButton(
            onPressed: busy ? null : _submit,
            child: Text(busy ? 'Menyimpan...' : 'Masuk'),
          ),
        ),
      ),
    );
  }
}

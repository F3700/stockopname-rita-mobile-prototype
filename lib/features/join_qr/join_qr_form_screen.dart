import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/session_repository.dart';
import '../../core/error/app_error.dart';
import '../../core/network/qr_join_api.dart';
import '../../core/ui/rita_dialog.dart';
import '../../core/ui/rita_theme.dart';
import '../catalog/sync_gate.dart';
import '../racks/rack_list_screen.dart';
import '../setup/setup_service.dart';
import 'join_qr_service.dart';

/// Form join via QR: coordinator_qr read-only + inspector + rak chip list.
/// POST hanya ke endpoint BARU (join-by-coordinator-qr).
class JoinQrFormScreen extends ConsumerStatefulWidget {
  const JoinQrFormScreen({
    super.key,
    required this.coordinatorQr,
    required this.preview,
  });
  final String coordinatorQr;
  final CoordinatorPreview preview;

  @override
  ConsumerState<JoinQrFormScreen> createState() => _JoinQrFormScreenState();
}

class _JoinQrFormScreenState extends ConsumerState<JoinQrFormScreen> {
  final inspectorCtrl = TextEditingController();
  final rakCtrl = TextEditingController();
  final rakNames = <String>[];
  bool busy = false;
  String? error;
  bool lastRetryable = false;

  @override
  void initState() {
    super.initState();
    // Listener lokal (tanpa ubah widget shared RitaInput) agar tombol
    // submit bisa aktif/mati mengikuti isi form.
    inspectorCtrl.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    inspectorCtrl.removeListener(_onFormChanged);
    inspectorCtrl.dispose();
    rakCtrl.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  /// Tombol aktif hanya bila koordinator IN_PROGRESS + inspector terisi +
  /// minimal 1 rak. Lapisan pertahanan klien; server tetap validator akhir
  /// (409 bila status berubah di tengah jalan).
  bool get canSubmit =>
      widget.preview.isJoinable &&
      inspectorCtrl.text.trim().isNotEmpty &&
      rakNames.isNotEmpty;

  /// Hint apa yang kurang agar tombol bisa ditekan.
  String? get missingHint {
    if (!widget.preview.isJoinable) {
      final st = widget.preview.status.trim().isEmpty
          ? '-'
          : widget.preview.status;
      return 'Koordinator tidak aktif (status: $st). '
          'Minta admin mengaktifkan sesi atau pindai QR lain.';
    }
    final inspectorEmpty = inspectorCtrl.text.trim().isEmpty;
    if (inspectorEmpty && rakNames.isEmpty) {
      return 'Isi kode inspector dan tambahkan minimal 1 rak.';
    }
    if (inspectorEmpty) return 'Isi kode inspector.';
    if (rakNames.isEmpty) return 'Tambahkan minimal 1 rak.';
    return null;
  }

  void _addRak() {
    final name = rakCtrl.text.trim();
    if (name.isEmpty) return;
    if (rakNames.contains(name)) {
      setState(() {
        error = 'Rak $name sudah ada di daftar.';
        lastRetryable = false;
      });
      return;
    }
    setState(() {
      rakNames.add(name);
      error = null;
      lastRetryable = false;
    });
    rakCtrl.clear();
  }

  Future<void> _submit() async {
    // Precheck client: hemat roundtrip + dialog sync yang berat bila kosong.
    if (!canSubmit) {
      setState(() {
        error = missingHint;
        lastRetryable = false;
      });
      return;
    }
    final container = ProviderScope.containerOf(context);
    setState(() {
      busy = true;
      error = null;
      lastRetryable = false;
    });
    try {
      // Gerbang sama seperti manual: wajib online + master segar.
      final proceed =
          await ensureOnlineAndFresh(context, container, 'Gabung via QR');
      if (!proceed || !mounted) return;
      final session = await ref.read(joinQrServiceProvider).joinViaQr(
            coordinatorQr: widget.coordinatorQr,
            inspectorCode: inspectorCtrl.text.trim(),
            rakNames: List.of(rakNames),
            sessionCode: widget.preview.sessionCode,
          );
      ref.read(activeSessionProvider.notifier).set(session);
      ref.invalidate(sessionListProvider);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RackListScreen()),
        (route) => route.isFirst,
      );
    } catch (e) {
      final msg = e is AppFailure ? e.userMessage : e.toString();
      final retryable = e is QrJoinFailure && e.retryable;
      if (mounted) {
        setState(() {
          error = msg;
          lastRetryable = retryable;
        });
        await showRitaError(
          context: context,
          title: 'Gagal gabung via QR',
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
            Text('Gabung via QR',
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            Text('Inspector + rak untuk koordinator ini',
                style: TextStyle(color: RitaColors.grey, fontSize: 12)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 50),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CoorHeaderCard(preview: widget.preview),
            RitaInput(
              controller: inspectorCtrl,
              title: 'Kode Inspektor',
              hint: 'contoh : BUDI',
              maxLength: 20,
              keyboardType: TextInputType.text,
            ),
            Container(
              padding: const EdgeInsets.all(15),
              margin: const EdgeInsets.all(10),
              width: double.infinity,
              decoration: BoxDecoration(
                border:
                    Border.all(color: const Color(0xFFD9D9D9)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'RAK (${rakNames.length})',
                      style: const TextStyle(
                          color: Color(0xFF616161),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0)),
                  TextField(
                    controller: rakCtrl,
                    maxLength: 10,
                    onSubmitted: (_) => _addRak(),
                    decoration: InputDecoration(
                      labelText: 'contoh: A-01',
                      labelStyle: const TextStyle(
                          fontSize: 12,
                          color: RitaColors.lightGrey),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide:
                            BorderSide(color: RitaColors.red),
                      ),
                      suffix: IconButton(
                        onPressed: _addRak,
                        icon: const Icon(Icons.add_circle,
                            color: RitaColors.red),
                      ),
                    ),
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  if (rakNames.isEmpty)
                    const Text('Belum ada rak. Minimal 1 rak.',
                        style: TextStyle(
                            color: RitaColors.grey, fontSize: 12)),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final name in rakNames)
                        Chip(
                          label: Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          side: const BorderSide(color: Colors.black),
                          deleteIcon: const Icon(Icons.close,
                              size: 18, color: RitaColors.red),
                          onDeleted: () =>
                              setState(() => rakNames.remove(name)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (!widget.preview.isJoinable)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 17, vertical: 4),
                child: Text(missingHint ?? '',
                    style: const TextStyle(
                        color: Colors.red, fontSize: 13)),
              )
            else if (!canSubmit && missingHint != null && !busy)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 17, vertical: 4),
                child: Text(missingHint!,
                    style: const TextStyle(
                        color: RitaColors.grey, fontSize: 12)),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(error!,
                        style:
                            const TextStyle(color: Colors.red)),
                    if (lastRetryable) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: busy ? null : _submit,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba lagi'),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FilledButton(
            onPressed: (canSubmit && !busy) ? _submit : null,
            child: Text(busy ? 'Menyimpan...' : 'Gabung & Mulai'),
          ),
        ),
      ),
    );
  }
}

/// Kartu info koordinator dari GET /stockopname/coordinators/{id}:
/// coordinator code, status, sesi code, lokasi. Nama = kode (DB tidak punya
/// kolom nama); statistik dibuang. Tampilan kartu dipertahankan.
class _CoorHeaderCard extends StatelessWidget {
  const _CoorHeaderCard({required this.preview});
  final CoordinatorPreview preview;

  @override
  Widget build(BuildContext context) {
    final code =
        preview.code.trim().isEmpty ? '-' : preview.code.trim();
    final active = preview.isJoinable;
    final statusLabel =
        preview.status.trim().isEmpty ? '-' : preview.status.trim();
    final sesi = preview.sessionCode.trim();
    final lokasi = preview.sessionLocation.trim();
    return Card(
      margin: const EdgeInsets.all(10),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Colors.black),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        // stretch agar kartu tetap full-width seperti sebelumnya
        // (dulu dipaksa oleh Expanded di baris status).
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dua kolom per baris; aman karena isi hanya teks
            // (bukan FilledButton yang sensitif lebar-tak-terbatas).
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _InfoRow(label: 'Koordinator', value: code),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoRow(
                    label: 'Status',
                    value: statusLabel,
                    valueColor:
                        active ? RitaColors.red : RitaColors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _InfoRow(
                    label: 'Sesi',
                    value: sesi.isEmpty
                        ? 'menunggu update backend'
                        : sesi,
                    muted: sesi.isEmpty,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoRow(
                    label: 'Lokasi',
                    value: lokasi.isEmpty ? '-' : lokasi,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu baris info: label abu kecil + nilai bold, selaras gaya RitaInput.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.muted = false,
    this.valueColor,
  });
  final String label;
  final String value;
  final bool muted;

  /// Warna nilai bila tidak redup; default hitam.
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
              color: RitaColors.grey,
              fontSize: 12,
              letterSpacing: 1.0,
            )),
        Text(value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: muted
                  ? RitaColors.lightGrey
                  : (valueColor ?? Colors.black),
              fontStyle: muted ? FontStyle.italic : FontStyle.normal,
            )),
      ],
    );
  }
}

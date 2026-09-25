import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/session_repository.dart';
import '../../core/error/app_error.dart';
import '../../core/network/qr_join_api.dart';
import '../../core/ui/design_system/rita_band.dart';
import '../../core/ui/design_system/rita_buttons.dart';
import '../../core/ui/design_system/rita_card.dart';
import '../../core/ui/design_system/rita_field.dart';
import '../../core/ui/design_system/rita_pill.dart';
import '../../core/ui/design_system/rita_tokens.dart';
import '../../core/ui/rita_dialog.dart';
import '../catalog/sync_gate.dart';
import '../racks/rack_list_screen.dart';
import '../setup/setup_service.dart';
import 'join_qr_service.dart';

/// Form join via QR (v5): kartu koordinator + inspektor + chip rak.
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
    // Listener lokal agar tombol submit aktif/mati mengikuti isi form.
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
      final proceed = await ensureOnlineAndFresh(
        context,
        container,
        'Gabung via QR',
      );
      if (!proceed || !mounted) return;
      final session = await ref
          .read(joinQrServiceProvider)
          .joinViaQr(
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
      appBar: RitaBand(
        title: 'Gabung via QR',
        subtitle: 'Inspector dan rak',
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
            _CoordinatorCard(preview: widget.preview),
            const SizedBox(height: RitaSpace.md),
            RitaField(
              label: 'KODE INSPEKTOR',
              controller: inspectorCtrl,
              hint: 'contoh: BUDI',
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: RitaSpace.lg),
            Text('RAK - MINIMAL 1', style: RitaType.sectionLabel),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: RitaSizes.field,
                    child: TextField(
                      controller: rakCtrl,
                      onSubmitted: (_) => _addRak(),
                      style: RitaType.body,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: RitaSpace.md,
                        ),
                        hintText: 'Mis. A-01',
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
              Wrap(
                spacing: RitaSpace.xs,
                runSpacing: RitaSpace.xs,
                children: [
                  for (final name in rakNames)
                    _RakChip(
                      label: name,
                      onDeleted: () => setState(() => rakNames.remove(name)),
                    ),
                ],
              ),
            ],
            if (!widget.preview.isJoinable)
              Padding(
                padding: const EdgeInsets.only(top: RitaSpace.sm),
                child: Text(
                  missingHint ?? '',
                  style: RitaType.caption.copyWith(color: RitaPalette.error),
                ),
              )
            else if (!canSubmit && missingHint != null && !busy)
              Padding(
                padding: const EdgeInsets.only(top: RitaSpace.sm),
                child: Text(missingHint!, style: RitaType.meta),
              ),
            if (error != null) ...[
              const SizedBox(height: RitaSpace.sm),
              Text(
                error!,
                style: RitaType.caption.copyWith(color: RitaPalette.error),
              ),
              if (lastRetryable) ...[
                const SizedBox(height: RitaSpace.xs),
                SizedBox(
                  width: 160,
                  child: RitaSecondaryButton(
                    label: 'Coba lagi',
                    icon: Icons.refresh,
                    onPressed: busy ? null : _submit,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(RitaSpace.screen),
          child: RitaPrimaryButton(
            label: 'GABUNG DAN MULAI',
            loading: busy,
            onPressed: (canSubmit && !busy) ? _submit : null,
          ),
        ),
      ),
    );
  }
}

/// Kartu info koordinator v5: code + pill status + sesi/gudang + jumlah rak.
class _CoordinatorCard extends StatelessWidget {
  const _CoordinatorCard({required this.preview});
  final CoordinatorPreview preview;

  @override
  Widget build(BuildContext context) {
    final code = preview.code.trim().isEmpty ? '-' : preview.code.trim();
    final active = preview.isJoinable;
    final status = preview.status.trim().isEmpty ? '-' : preview.status.trim();
    final sesi = preview.sessionCode.trim();
    final lokasi = preview.sessionLocation.trim();
    return RitaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [Expanded(child: Text(code, style: RitaType.title))],
          ),
          const SizedBox(height: RitaSpace.xs),
          active
              ? RitaPill(
                  label: status,
                  bg: RitaPalette.successBg,
                  fg: RitaPalette.successText,
                )
              : RitaPill(
                  label: status,
                  bg: RitaPalette.neutral,
                  fg: RitaPalette.grey,
                  border: RitaPalette.border,
                ),
          const SizedBox(height: RitaSpace.sm),
          Text(
            'Sesi ${sesi.isEmpty ? '-' : sesi}${lokasi.isEmpty ? '' : ' - $lokasi'}',
            style: RitaType.body15,
          ),
          const SizedBox(height: 4),
          Text(
            '${preview.rackAssigned} rak didaftarkan koordinator',
            style: RitaType.caption,
          ),
        ],
      ),
    );
  }
}

/// Chip rak v5: putih border, label 14/700, tombol × 24 dengan target 44.
class _RakChip extends StatelessWidget {
  const _RakChip({required this.label, required this.onDeleted});

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.only(left: RitaSpace.md),
      decoration: BoxDecoration(
        color: RitaPalette.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RitaPalette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          SizedBox(
            width: RitaSizes.iconTarget,
            height: 40,
            child: IconButton(
              onPressed: onDeleted,
              tooltip: 'Hapus $label',
              iconSize: 20,
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.close, color: RitaPalette.grey),
            ),
          ),
        ],
      ),
    );
  }
}

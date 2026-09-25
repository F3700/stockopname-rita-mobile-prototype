import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/session_repository.dart';
import '../../core/ui/design_system/rita_band.dart';
import '../../core/ui/design_system/rita_buttons.dart';
import '../../core/ui/design_system/rita_card.dart';
import '../../core/ui/design_system/rita_feedback.dart';
import '../../core/ui/design_system/rita_pill.dart';
import '../../core/ui/design_system/rita_search.dart';
import '../../core/ui/design_system/rita_states.dart';
import '../../core/ui/design_system/rita_tokens.dart';
import '../../core/ui/rita_dialog.dart';
import '../../core/ui/rita_theme.dart';
import '../catalog/sync_gate.dart';
import '../scan/rack_scan_screen.dart';
import '../setup/setup_service.dart';
import 'rack_providers.dart';

/// Daftar rak sesi aktif (v5): progres + cari + tambah + selesai (lokal).
class RackListScreen extends ConsumerStatefulWidget {
  const RackListScreen({super.key});

  @override
  ConsumerState<RackListScreen> createState() => _RackListScreenState();
}

class _RackListScreenState extends ConsumerState<RackListScreen> {
  final searchCtrl = TextEditingController();
  String query = '';

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Daftar Rak')),
        body: const Center(child: Text('Tidak ada sesi aktif.')),
      );
    }
    final racks = ref.watch(rackListProvider(session.inspectorId));

    return Scaffold(
      appBar: RitaBand(
        title: session.sesiCode,
        subtitle: session.inspectorCode,
        onBack: () => Navigator.of(context).pop(),
        trailing: RitaPill.status(RitaStatus.berjalan),
      ),
      body: racks.when(
        data: (rows) {
          final filtered = query.isEmpty
              ? rows
              : rows
                    .where(
                      (r) => r.name.toLowerCase().contains(query.toLowerCase()),
                    )
                    .toList();
          final done = rows.where((r) => r.done).length;
          final total = rows.length;
          final progress = total == 0 ? 0.0 : done / total;
          final uploaded = rows.where((r) => r.isUploaded).length;
          return RefreshIndicator(
            color: RitaPalette.primary,
            onRefresh: () async =>
                ref.invalidate(rackListProvider(session.inspectorId)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                RitaSpace.screen,
                RitaSpace.md,
                RitaSpace.screen,
                96,
              ),
              children: [
                _ProgressCard(
                  done: done,
                  total: total,
                  progress: progress,
                  uploaded: uploaded,
                ),
                const SizedBox(height: RitaSpace.sm),
                RitaSearchField(
                  controller: searchCtrl,
                  hint: 'Cari rak...',
                  onChanged: (v) => setState(() => query = v),
                ),
                const SizedBox(height: RitaSpace.sm),
                if (rows.isEmpty)
                  RitaEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'Belum ada rak',
                    message: 'Tambahkan rak untuk mulai memindai.',
                    actionLabel: 'Tambah rak',
                    onAction: () => _addRak(context, session.inspectorId),
                  )
                else if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(
                      child: Text('Rak tidak ditemukan.', style: RitaType.meta),
                    ),
                  )
                else
                  for (final r in filtered) ...[
                    _RakCard(row: r),
                    const SizedBox(height: RitaSpace.sm),
                  ],
              ],
            ),
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(RitaSpace.screen),
          child: RitaListSkeleton(height: 96),
        ),
        error: (e, _) =>
            Center(child: Text('Gagal memuat rak: $e', style: RitaType.meta)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: RitaPalette.primary,
        foregroundColor: Colors.white,
        onPressed: () => _addRak(context, session.inspectorId),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            RitaSpace.screen,
            RitaSpace.xs,
            RitaSpace.screen,
            RitaSpace.screen,
          ),
          child: RitaPrimaryButton(
            label: 'SELESAIKAN SESI',
            onPressed: () => _finish(context),
          ),
        ),
      ),
    );
  }

  Future<void> _addRak(BuildContext context, int inspectorId) async {
    final ctrl = TextEditingController();
    try {
      final name = await showRitaDialog<String>(
        context: context,
        builder: (ctx) => RitaAlert(
          title: const Text('Tambah Rak'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Nomor rak, contoh: 1021',
            ),
            onSubmitted: (_) => Navigator.pop(ctx, ctrl.text.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Tambah'),
            ),
          ],
        ),
      );
      if (name == null || name.isEmpty) return;
      try {
        await ref
            .read(setupServiceProvider)
            .addRak(inspectorId: inspectorId, rakName: name);
        ref.invalidate(rackListProvider);
      } catch (e) {
        if (context.mounted) {
          showRitaToast(context, e.toString());
        }
      }
    } finally {
      ctrl.dispose();
    }
  }

  Future<void> _finish(BuildContext context) async {
    final session = ref.read(activeSessionProvider);
    if (session == null) return;
    final ok = await showRitaDialog<bool>(
      context: context,
      builder: (ctx) => RitaAlert(
        title: const Text('Selesaikan sesi?'),
        content: const Text(
          'Sesi ditandai selesai (lokal). Data yang belum terupload tetap tersimpan di perangkat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(setupServiceProvider).finishSession(session);
    ref.read(activeSessionProvider.notifier).set(null);
    ref.invalidate(sessionListProvider);
    if (context.mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.done,
    required this.total,
    required this.progress,
    required this.uploaded,
  });
  final int done;
  final int total;
  final double progress;
  final int uploaded;

  @override
  Widget build(BuildContext context) {
    return RitaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$done dari $total rak selesai',
                  style: RitaType.strong15,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: RitaType.strong15.copyWith(color: RitaPalette.primary),
              ),
            ],
          ),
          const SizedBox(height: RitaSpace.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: RitaPalette.track,
              valueColor: const AlwaysStoppedAnimation(RitaPalette.primary),
            ),
          ),
          if (total > 0) ...[
            const SizedBox(height: RitaSpace.xs),
            Text(
              '$uploaded dari $total rak terupload',
              style: RitaType.caption,
            ),
          ],
        ],
      ),
    );
  }
}

class _RakCard extends ConsumerWidget {
  const _RakCard({required this.row});
  final RakRow row;

  /// Anti-tumpuk double-tap: abaikan tap kedua dalam 800ms.
  static DateTime? _lastTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RitaCard(
      onTap: () async {
        final now = DateTime.now();
        if (_lastTap != null &&
            now.difference(_lastTap!).inMilliseconds < 800) {
          return;
        }
        _lastTap = now;
        // Gerbang: wajib online saja untuk masuk rak.
        final container = ProviderScope.containerOf(context);
        final proceed = await requireOnline(context, container, 'Membuka rak');
        if (!proceed || !context.mounted) return;
        final session = ref.read(activeSessionProvider);
        if (session == null) return;
        ref
            .read(activeSessionProvider.notifier)
            .set(
              session.copyWith(
                currentRakId: row.rakId,
                currentRakName: row.name,
              ),
            );
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RackScanScreen(rakId: row.rakId, rakName: row.name),
          ),
        );
        // Refresh statistik (pending/total) sepulang dari layar scan.
        ref.invalidate(rackListProvider(session.inspectorId));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(row.name, style: RitaType.title)),
              row.done
                  ? RitaPill.status(RitaStatus.selesai)
                  : RitaPill.status(RitaStatus.proses),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${row.stats.totalQty} barang • Rp${rupiah(row.stats.totalValue)}',
            style: RitaType.meta,
          ),
          const SizedBox(height: 4),
          _UploadStatus(row: row),
        ],
      ),
    );
  }
}

/// Status upload tingkat rak (bukan per produk).
class _UploadStatus extends StatelessWidget {
  const _UploadStatus({required this.row});
  final RakRow row;

  @override
  Widget build(BuildContext context) {
    if (row.stats.itemCount == 0) {
      return Text('Kosong', style: RitaType.captionHint);
    }
    if (row.isUploaded) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, size: 16, color: RitaPalette.successText),
          const SizedBox(width: 4),
          Text(
            'Terupload',
            style: RitaType.caption.copyWith(color: RitaPalette.successText),
          ),
        ],
      );
    }
    return Text(
      'Belum upload',
      style: RitaType.caption.copyWith(color: RitaPalette.warningText),
    );
  }
}

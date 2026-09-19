import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/session_repository.dart';
import '../../core/ui/rita_dialog.dart';
import '../../core/ui/rita_theme.dart';
import '../catalog/sync_gate.dart';
import '../scan/rack_scan_screen.dart';
import '../setup/setup_service.dart';
import 'rack_providers.dart';

/// Daftar rak sesi aktif: progres + cari + tambah + selesai (lokal).
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
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: RitaColors.red,
        foregroundColor: Colors.white,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(session.sesiCode,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            Text(session.inspectorCode,
                style: const TextStyle(
                    fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: racks.when(
        data: (rows) {
          final filtered = query.isEmpty
              ? rows
              : rows
                  .where((r) => r.name
                      .toLowerCase()
                      .contains(query.toLowerCase()))
                  .toList();
          final done = rows.where((r) => r.done).length;
          final total = rows.length;
          final progress = total == 0 ? 0.0 : done / total;
          final uploaded =
              rows.where((r) => r.isUploaded).length;
          return RefreshIndicator(
            color: RitaColors.red,
            onRefresh: () async =>
                ref.invalidate(rackListProvider(session.inspectorId)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _ProgressCard(
                  done: done,
                  total: total,
                  progress: progress,
                  uploaded: uploaded,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: searchCtrl,
                  onChanged: (v) => setState(() => query = v),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.search,
                        color: Colors.grey),
                    hintText: 'Cari rak...',
                    hintStyle:
                        const TextStyle(color: Colors.grey),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(
                        child: Text('Tidak ada rak.',
                            style:
                                TextStyle(color: RitaColors.grey))),
                  )
                else
                  ...filtered.map((r) => _RakCard(row: r)),
              ],
            ),
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat rak: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: RitaColors.red,
        foregroundColor: Colors.white,
        onPressed: () => _addRak(context, session.inspectorId),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            onPressed: () => _finish(context),
            child: const Text('Selesai'),
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
                labelText: 'Nomor rak, contoh: 1021'),
            onSubmitted: (_) => Navigator.pop(ctx, ctrl.text.trim()),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal')),
            FilledButton(
                onPressed: () =>
                    Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('Tambah')),
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
          hideStackedSnackBar(context);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString())));
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
            'Sesi ditandai selesai (lokal). Data yang belum terupload tetap tersimpan di perangkat.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Selesai')),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$done dari $total rak selesai',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              Text('${(progress * 100).round()}%',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: RitaColors.red)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: RitaColors.red.withValues(alpha: 0.12),
              valueColor:
                  const AlwaysStoppedAnimation(RitaColors.red),
            ),
          ),
          if (total > 0) ...[
            const SizedBox(height: 8),
            Text('$uploaded dari $total rak terupload',
                style: const TextStyle(
                    fontSize: 12, color: RitaColors.grey)),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final now = DateTime.now();
          if (_lastTap != null &&
              now.difference(_lastTap!).inMilliseconds < 800) {
            return;
          }
          _lastTap = now;
          // Gerbang: wajib online saja untuk masuk rak.
          final container = ProviderScope.containerOf(context);
          final proceed =
              await requireOnline(context, container, 'Membuka rak');
          if (!proceed || !context.mounted) return;
          final session = ref.read(activeSessionProvider);
          if (session == null) return;
          ref.read(activeSessionProvider.notifier).set(session.copyWith(
              currentRakId: row.rakId, currentRakName: row.name));
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => RackScanScreen(
                  rakId: row.rakId, rakName: row.name)));
          // Refresh statistik (pending/total) sepulang dari layar scan.
          ref.invalidate(rackListProvider(session.inspectorId));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: 14, horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(row.name,
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold)),
                        ),
                        _StatusPill(done: row.done),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${row.stats.totalQty} barang • Rp${rupiah(row.stats.totalValue)}',
                      style: const TextStyle(
                          color: RitaColors.grey, fontSize: 13),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: _UploadStatus(row: row),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
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
      return const Text('Kosong',
          style: TextStyle(color: RitaColors.grey, fontSize: 12));
    }
    if (row.isUploaded) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 14),
          SizedBox(width: 4),
          Text('Terupload',
              style: TextStyle(color: Colors.green, fontSize: 12)),
        ],
      );
    }
    return const Text('Belum upload',
        style: TextStyle(color: Colors.orange, fontSize: 12));
  }
}

class _StatusPill extends StatelessWidget {  const _StatusPill({required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
      decoration: BoxDecoration(
        color: done ? RitaColors.red : RitaColors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        done ? 'Selesai' : 'Proses',
        style: TextStyle(
            color: done ? Colors.white : RitaColors.red,
            fontSize: 12,
            fontWeight: FontWeight.bold),
      ),
    );
  }
}

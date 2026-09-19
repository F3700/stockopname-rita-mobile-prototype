import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/session_repository.dart';
import '../../core/database/sync_meta_repository.dart';
import '../../core/ui/rita_dialog.dart';
import '../../core/ui/rita_theme.dart';
import '../join_qr/scan_coordinator_screen.dart';
import '../racks/rack_list_screen.dart';
import '../setup/session_form_screen.dart';
import '../setup/setup_service.dart';

/// Home ala Niko: mulai sesi (kode saja) + riwayat sesi lokal.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionListProvider);
    final lastSync = ref.watch(lastSyncProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: RitaColors.red,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Stock Scanner',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 20)),
                  lastSync.when(
                    data: (t) => Text(
                      t == null
                          ? 'Belum pernah sinkronisasi'
                          : 'last Updated : ${t.toLocal().toString().substring(0, 19)}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    loading: () => const Text('',
                        style: TextStyle(fontSize: 12, color: Colors.white)),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const CircleAvatar(
              backgroundColor: Colors.white,
              child: ClipOval(
                child: Image(
                  image: AssetImage('assets/images/logoritapasaraya.png'),
                  fit: BoxFit.cover,
                  width: 36,
                  height: 36,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(17),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: RitaColors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const SessionFormScreen()));
              },
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.document_scanner_outlined,
                        size: 72, color: RitaColors.red),
                    SizedBox(height: 8),
                    Text('Mulai stock opname',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20)),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.only(left: 17, right: 17, bottom: 17),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: RitaColors.red,
                side: const BorderSide(color: RitaColors.red),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ScanCoordinatorScreen()));
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR Coordinator',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 17),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Riwayat Sesi',
                  style: TextStyle(color: RitaColors.grey)),
            ),
          ),
          Expanded(
            child: sessions.when(
              data: (rows) {
                if (rows.isEmpty) {
                  return const Center(
                      child: Text('Belum ada sesi. Mulai stock opname dulu.',
                          style: TextStyle(color: RitaColors.grey)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(17),
                  itemCount: rows.length,
                  itemBuilder: (_, i) => _SessionCard(row: rows[i]),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = row['status'] == SessionRepository.statusDone;
    final created =
        (row['created_at'] as String?)?.substring(0, 19) ?? '-';
    final finished = row['finished_at'] as String?;
    final coor = (row['coor_code'] as String?)?.trim() ?? '';
    final inspector = (row['inspector_code'] as String?)?.trim() ?? '';
    return Card(
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Colors.black),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _enter(context, ref),
        child: Padding(
          padding:
              const EdgeInsets.only(top: 7, left: 17, bottom: 10, right: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${row['sesi_code']}',
                        style: const TextStyle(
                            color: Colors.black, fontSize: 16)),
                    if (coor.isNotEmpty || inspector.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Koor: ${coor.isEmpty ? '-' : coor} • Insp: ${inspector.isEmpty ? '-' : inspector}',
                        style: const TextStyle(
                            color: RitaColors.grey, fontSize: 12),
                      ),
                    ],
                    if (row['join_via'] == 'qr') ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 1, horizontal: 8),
                        decoration: BoxDecoration(
                          color: RitaColors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('via QR',
                            style: TextStyle(
                                color: RitaColors.red, fontSize: 12)),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 1, horizontal: 8),
                      decoration: BoxDecoration(
                        color: done ? RitaColors.red : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: RitaColors.red),
                      ),
                      child: Text(
                        done ? 'Selesai' : 'Belum Selesai',
                        style: TextStyle(
                            color: done ? Colors.white : RitaColors.red,
                            fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      done && finished != null
                          ? finished.substring(0, 19)
                          : created,
                      style: const TextStyle(
                          color: RitaColors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete,
                    color: RitaColors.red, size: 30),
                onPressed: () => _confirmDelete(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Masuk ke daftar rak sesi ini (riwayat bisa dilanjutkan lagi).
  /// Tanpa gerbang — langsung masuk.
  Future<void> _enter(BuildContext context, WidgetRef ref) async {
    final inspectorId = (row['inspector_id'] as num).toInt();
    final racks = await ref
        .read(sessionRepositoryProvider)
        .racksOfInspector(inspectorId);
    // currentRak hanya penanda — layar rak/scan bawa rakId sendiri.
    final first = racks.isEmpty ? null : racks.first;
    ref.read(activeSessionProvider.notifier).set(ActiveSession(
          dbId: (row['id'] as num).toInt(),
          sesiCode: row['sesi_code'] as String,
          coorCode: row['coor_code'] as String,
          inspectorCode: row['inspector_code'] as String,
          inspectorId: inspectorId,
          currentRakId: first == null
              ? 0
              : (first['rak_id'] as num).toInt(),
          currentRakName:
              first == null ? '' : first['name'] as String,
        ));
    if (context.mounted) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const RackListScreen()));
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showRitaConfirm(
      context: context,
      title: 'Hapus riwayat?',
      message:
          'Riwayat sesi ${row['sesi_code']} dihapus dari daftar. Data rak & hasil scan tetap aman di perangkat.',
      cancelLabel: 'Batal',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (ok == true) {
      await ref
          .read(sessionRepositoryProvider)
          .delete((row['id'] as num).toInt());
      ref.invalidate(sessionListProvider);
    }
  }
}

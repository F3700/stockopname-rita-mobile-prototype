import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connectivity/connectivity_providers.dart';
import '../../core/database/session_repository.dart';
import '../../core/database/sync_meta_repository.dart';
import '../../core/ui/design_system/rita_band.dart';
import '../../core/ui/design_system/rita_buttons.dart';
import '../../core/ui/design_system/rita_card.dart';
import '../../core/ui/design_system/rita_pill.dart';
import '../../core/ui/design_system/rita_states.dart';
import '../../core/ui/design_system/rita_tokens.dart';
import '../../core/ui/rita_dialog.dart';
import '../join_qr/scan_coordinator_screen.dart';
import '../racks/rack_list_screen.dart';
import '../setup/session_form_screen.dart';
import '../setup/setup_service.dart';

/// Home v5: band compact + CTA ganda + riwayat sesi lokal.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _openSessionForm(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SessionFormScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionListProvider);
    final lastSync = ref.watch(lastSyncProvider);
    final online = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: RitaBand(
        title: 'Stock Scanner',
        subtitle: _syncSubtitle(lastSync, online),
        subtitleDot: online ? RitaPalette.success : RitaPalette.warning,
        trailing: const _LogoAvatar(),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              RitaSpace.screen,
              RitaSpace.md,
              RitaSpace.screen,
              0,
            ),
            child: Column(
              children: [
                RitaPrimaryButton(
                  label: 'MULAI STOCK OPNAME',
                  onPressed: () => _openSessionForm(context),
                ),
                const SizedBox(height: RitaSpace.sm),
                RitaSecondaryButton(
                  label: 'SCAN QR COORDINATOR',
                  icon: Icons.qr_code_scanner,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ScanCoordinatorScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: RitaSpace.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RitaSpace.screen),
            child: Row(
              children: [
                Text('RIWAYAT SESI', style: RitaType.sectionLabel),
                const Spacer(),
                sessions.maybeWhen(
                  data: (rows) =>
                      Text('${rows.length}', style: RitaType.caption),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(height: RitaSpace.xs),
          Expanded(
            child: sessions.when(
              data: (rows) {
                if (rows.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(RitaSpace.screen),
                    children: [
                      RitaEmptyState(
                        icon: Icons.history,
                        title: 'Belum ada sesi',
                        message:
                            'Mulai stock opname atau pindai QR koordinator untuk memulai.',
                        actionLabel: 'Mulai stock opname',
                        onAction: () => _openSessionForm(context),
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    RitaSpace.screen,
                    RitaSpace.xs,
                    RitaSpace.screen,
                    RitaSpace.screen,
                  ),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: RitaSpace.sm),
                  itemBuilder: (_, i) => _SessionCard(row: rows[i]),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(RitaSpace.screen),
                child: RitaListSkeleton(),
              ),
              error: (e, _) =>
                  Center(child: Text('Gagal memuat: $e', style: RitaType.meta)),
            ),
          ),
        ],
      ),
    );
  }

  static String _syncSubtitle(AsyncValue<DateTime?> lastSync, bool online) {
    if (!online) return 'Offline - data lokal';
    return lastSync.maybeWhen(
      data: (t) => t == null
          ? 'Belum pernah sinkronisasi'
          : 'Tersinkron ${t.toLocal().toString().substring(0, 16)}',
      orElse: () => 'Memeriksa sinkronisasi...',
    );
  }
}

/// Avatar 40px di slot kanan band.
class _LogoAvatar extends StatelessWidget {
  const _LogoAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: RitaPalette.white,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: const Image(
        image: AssetImage('assets/images/logoritapasaraya.png'),
        fit: BoxFit.cover,
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
    final created = (row['created_at'] as String?)?.substring(0, 19) ?? '-';
    final finished = row['finished_at'] as String?;
    final coor = (row['coor_code'] as String?)?.trim() ?? '';
    final inspector = (row['inspector_code'] as String?)?.trim() ?? '';
    final viaQr = row['join_via'] == 'qr';

    return RitaCard(
      onTap: () => _enter(context, ref),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${row['sesi_code']}', style: RitaType.title),
                if (coor.isNotEmpty || inspector.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Koor: ${coor.isEmpty ? '-' : coor} • Insp: ${inspector.isEmpty ? '-' : inspector}',
                    style: RitaType.meta,
                  ),
                ],
                const SizedBox(height: RitaSpace.xs + 2),
                Row(
                  children: [
                    done
                        ? RitaPill.status(RitaStatus.selesai)
                        : RitaPill.status(RitaStatus.berjalan),
                    if (viaQr) ...[
                      const SizedBox(width: RitaSpace.xs),
                      RitaPill.tag('via QR'),
                    ],
                  ],
                ),
                const SizedBox(height: RitaSpace.xs + 2),
                Text(
                  done && finished != null
                      ? finished.substring(0, 19)
                      : created,
                  style: RitaType.captionHint,
                ),
              ],
            ),
          ),
          RitaIconButton(
            icon: Icons.delete_outline,
            color: RitaPalette.primary,
            tooltip: 'Hapus riwayat',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
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
    ref
        .read(activeSessionProvider.notifier)
        .set(
          ActiveSession(
            dbId: (row['id'] as num).toInt(),
            sesiCode: row['sesi_code'] as String,
            coorCode: row['coor_code'] as String,
            inspectorCode: row['inspector_code'] as String,
            inspectorId: inspectorId,
            currentRakId: first == null ? 0 : (first['rak_id'] as num).toInt(),
            currentRakName: first == null ? '' : first['name'] as String,
          ),
        );
    if (context.mounted) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const RackListScreen()));
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

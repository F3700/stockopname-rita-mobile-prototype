import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/session_repository.dart';
import '../../core/database/so_repository.dart';

/// Satu baris rak + statistik isinya untuk layar daftar rak.
class RakRow {
  const RakRow({
    required this.rakId,
    required this.name,
    required this.done,
    required this.stats,
  });

  final int rakId;
  final String name;
  final bool done;
  final RakStats stats;

  /// true bila rak berisi barang dan semuanya sudah terupload.
  bool get isUploaded => stats.itemCount > 0 && stats.pendingCount == 0;
}

/// Daftar rak sesi aktif beserta statistik. Invalidate tiap ada perubahan.
final rackListProvider =
    FutureProvider.family<List<RakRow>, int>((ref, inspectorId) async {
  final sessions = ref.watch(sessionRepositoryProvider);
  final so = ref.watch(soRepositoryProvider);
  final racks = await sessions.racksOfInspector(inspectorId);
  final rows = <RakRow>[];
  for (final r in racks) {
    final rakId = (r['rak_id'] as num).toInt();
    rows.add(RakRow(
      rakId: rakId,
      name: r['name'] as String,
      done: ((r['done'] as num?) ?? 0).toInt() == 1,
      stats: await so.statsByRak(rakId),
    ));
  }
  return rows;
});

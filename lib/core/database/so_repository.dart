import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dto.dart';
import 'app_database.dart';

final soRepositoryProvider = Provider<SoRepository>((ref) {
  return SoRepository(ref.watch(databaseProvider));
});

/// Hasil scan per rak. UNIQUE(rak_id, product_id) mirror Postgres.
class SoRepository {
  SoRepository(this._db);
  final AppDatabase _db;

  Future<Map<String, dynamic>?> findByRakAndProduct(
      int rakId, int productId) async {
    final db = await _db.db;
    final rows = await db.query('so_items',
        where: 'rak_id = ? AND product_id = ?',
        whereArgs: [rakId, productId],
        limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  /// mode: 'add' (tambah) atau 'replace' (ganti). Kembalikan qty akhir.
  Future<int> upsertScan({
    required int rakId,
    required String rakName,
    required int productId,
    required String barcode,
    required String productName,
    required int quantity,
    required String mode,
  }) async {
    final db = await _db.db;
    final existing = await findByRakAndProduct(rakId, productId);
    final now = DateTime.now().toIso8601String();
    if (existing == null) {
      await db.insert('so_items', {
        'rak_id': rakId,
        'rak_name': rakName,
        'product_id': productId,
        'barcode': barcode,
        'product_name': productName,
        'quantity': quantity,
        'status': SoStatus.pending,
        'attempts': 0,
        'updated_locally': now,
      });
      return quantity;
    }
    final oldQty = (existing['quantity'] as num).toInt();
    final nextQty = mode == 'add' ? oldQty + quantity : quantity;
    await db.update(
      'so_items',
      {
        'quantity': nextQty,
        // Edit lokal membuat item perlu upload ulang.
        'status': SoStatus.pending,
        'updated_locally': now,
      },
      where: 'rak_id = ? AND product_id = ?',
      whereArgs: [rakId, productId],
    );
    return nextQty;
  }

  Future<List<Map<String, dynamic>>> listByRak(int rakId) async {
    final db = await _db.db;
    return db.query('so_items',
        where: 'rak_id = ?', whereArgs: [rakId], orderBy: 'updated_locally DESC');
  }

  Future<List<Map<String, dynamic>>> pendingByRak(int rakId) async {
    final db = await _db.db;
    return db.query('so_items',
        where: 'rak_id = ? AND status IN (?, ?)',
        whereArgs: [rakId, SoStatus.pending, SoStatus.failed]);
  }

  Future<int> countPending() async {
    final db = await _db.db;
    final rows = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM so_items WHERE status IN ('${SoStatus.pending}','${SoStatus.failed}')");
    return ((rows.first['c']) as num).toInt();
  }

  Future<void> markSyncing(int rakId) async {
    final db = await _db.db;
    await db.update(
      'so_items',
      {'status': SoStatus.syncing, 'attempts': 1},
      where: 'rak_id = ? AND status IN (?, ?)',
      whereArgs: [rakId, SoStatus.pending, SoStatus.failed],
    );
  }

  Future<void> markSynced(int rakId) async {
    final db = await _db.db;
    await db.update(
      'so_items',
      {'status': SoStatus.synced, 'last_error': null},
      where: 'rak_id = ? AND status = ?',
      whereArgs: [rakId, SoStatus.syncing],
    );
  }

  Future<void> markFailed(int rakId, String error) async {
    final db = await _db.db;
    await db.update(
      'so_items',
      {'status': SoStatus.failed, 'last_error': error},
      where: 'rak_id = ? AND status = ?',
      whereArgs: [rakId, SoStatus.syncing],
    );
  }

  List<SoUploadItem> toUploadItems(List<Map<String, dynamic>> rows) => rows
      .map((r) => SoUploadItem(
            productId: (r['product_id'] as num).toInt(),
            rakId: (r['rak_id'] as num).toInt(),
            quantity: (r['quantity'] as num).toInt(),
          ))
      .toList();

  /// Statistik satu rak untuk kartu daftar rak.
  Future<RakStats> statsByRak(int rakId) async {
    final db = await _db.db;
    final rows = await db.rawQuery('''
      SELECT
        COUNT(s.local_id) AS item_count,
        COALESCE(SUM(s.quantity), 0) AS total_qty,
        COALESCE(SUM(CASE WHEN s.status IN ('${SoStatus.pending}','${SoStatus.failed}') THEN 1 ELSE 0 END), 0) AS pending_count,
        COALESCE(SUM(s.quantity * COALESCE(p.sell_price, 0)), 0) AS total_value
      FROM so_items s
      LEFT JOIN products p ON p.product_id = s.product_id
      WHERE s.rak_id = ?
    ''', [rakId]);
    final r = rows.first;
    return RakStats(
      itemCount: ((r['item_count']) as num).toInt(),
      totalQty: ((r['total_qty']) as num).toInt(),
      pendingCount: ((r['pending_count']) as num).toInt(),
      totalValue: ((r['total_value']) as num).toDouble(),
    );
  }
}

/// Ringkasan isi satu rak.
class RakStats {
  const RakStats({
    required this.itemCount,
    required this.totalQty,
    required this.pendingCount,
    required this.totalValue,
  });

  final int itemCount;
  final int totalQty;
  final int pendingCount;
  final double totalValue;
}

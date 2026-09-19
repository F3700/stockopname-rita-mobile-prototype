import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

final syncMetaRepositoryProvider = Provider<SyncMetaRepository>((ref) {
  return SyncMetaRepository(ref.watch(databaseProvider));
});

/// Waktu sync master terakhir (header Home). Invalidate setelah sync jalan.
final lastSyncProvider = FutureProvider<DateTime?>((ref) {
  return ref.watch(syncMetaRepositoryProvider).getLastProductSync();
});

class SyncMetaRepository {
  SyncMetaRepository(this._db);
  final AppDatabase _db;

  static const lastProductSyncKey = 'last_product_sync_at';

  Future<DateTime?> getLastProductSync() async {
    final db = await _db.db;
    final rows = await db.query('sync_meta',
        where: 'key = ?', whereArgs: [lastProductSyncKey], limit: 1);
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['value'] as String);
  }

  Future<void> setLastProductSync(DateTime value) async {
    final db = await _db.db;
    await db.insert(
      'sync_meta',
      {'key': lastProductSyncKey, 'value': value.toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(ref.watch(databaseProvider));
});

/// Riwayat sesi untuk Home. Invalidate setelah mulai/selesai/hapus sesi.
final sessionListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(sessionRepositoryProvider).list();
});

/// Riwayat sesi stock opname (lokal). ACTIVE = berjalan, DONE = selesai lokal.
class SessionRepository {
  SessionRepository(this._db);
  final AppDatabase _db;

  static const statusActive = 'ACTIVE';
  static const statusDone = 'DONE';

  /// [joinVia]: 'manual' (default, flow lama) atau 'qr' (flow scan QR).
  /// Kolom `join_via` ada sejak migrasi DB v3; default menjaga flow manual.
  Future<int> create({
    required String sesiCode,
    required String coorCode,
    required String inspectorCode,
    required int inspectorId,
    String joinVia = 'manual',
  }) async {
    final db = await _db.db;
    return db.insert('sessions', {
      'sesi_code': sesiCode,
      'coor_code': coorCode,
      'inspector_code': inspectorCode,
      'inspector_id': inspectorId,
      'join_via': joinVia,
      'status': statusActive,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> list() async {
    final db = await _db.db;
    return db.query('sessions', orderBy: 'id DESC');
  }

  Future<Map<String, dynamic>?> findActive() async {
    final db = await _db.db;
    final rows = await db.query('sessions',
        where: 'status = ?',
        whereArgs: [statusActive],
        orderBy: 'id DESC',
        limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> markDone(int id) async {
    final db = await _db.db;
    await db.update(
      'sessions',
      {
        'status': statusDone,
        'finished_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Hapus baris riwayat saja — data rak & hasil scan tetap aman.
  Future<void> delete(int id) async {
    final db = await _db.db;
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> racksOfInspector(int inspectorId) async {
    final db = await _db.db;
    return db.query('racks',
        where: 'inspector_id = ?', whereArgs: [inspectorId], orderBy: 'name');
  }

  Future<int> addLocalRak({
    required int rakId,
    required String name,
    required int inspectorId,
  }) async {
    final db = await _db.db;
    return db.insert(
      'racks',
      {'rak_id': rakId, 'name': name, 'inspector_id': inspectorId, 'done': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markRakDone(int rakId) async {
    final db = await _db.db;
    await db.update('racks', {'done': 1},
        where: 'rak_id = ?', whereArgs: [rakId]);
  }

  Future<void> markRaksDoneByInspector(int inspectorId) async {
    final db = await _db.db;
    await db.update('racks', {'done': 1},
        where: 'inspector_id = ?', whereArgs: [inspectorId]);
  }
}

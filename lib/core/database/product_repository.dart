import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/network/dto.dart';
import 'app_database.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.watch(databaseProvider));
});

/// Lookup barcode SELALU via indexed query, tidak pernah load 250k ke memori.
class ProductRepository {
  ProductRepository(this._db);
  final AppDatabase _db;

  Future<Map<String, dynamic>?> findByBarcode(String barcode) async {
    final db = await _db.db;
    final rows = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> upsertAll(List<ProductDto> items) async {
    if (items.isEmpty) return;
    final db = await _db.db;
    final batch = db.batch();
    for (final item in items) {
      batch.insert(
        'products',
        item.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteByIds(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await _db.db;
    final batch = db.batch();
    for (final id in ids) {
      batch.delete('products', where: 'product_id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  Future<int> count() async {
    final db = await _db.db;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM products');
    return ((rows.first['c']) as num).toInt();
  }

  Future<List<Map<String, dynamic>>> searchByName(String keyword,
      {int limit = 20}) async {
    final db = await _db.db;
    return db.query(
      'products',
      where: 'name LIKE ?',
      whereArgs: ['%$keyword%'],
      limit: limit,
    );
  }
}

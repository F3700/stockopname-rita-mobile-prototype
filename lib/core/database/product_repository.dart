import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/network/dto.dart';
import 'app_database.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.watch(databaseProvider));
});

/// Master produk lokal. Lookup barcode SELALU via indexed query (PK
/// product_barcodes), tidak pernah load 250k ke memori.
/// Satu produk bisa punya banyak barcode — semua bisa di-scan offline.
class ProductRepository {
  ProductRepository(this._db);
  final AppDatabase _db;

  Future<Map<String, dynamic>?> findByBarcode(String barcode) async {
    final db = await _db.db;
    final rows = await db.rawQuery(
      'SELECT p.* FROM product_barcodes b '
      'JOIN products p ON p.product_id = b.product_id '
      'WHERE b.barcode = ? LIMIT 1',
      [barcode],
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
      // Barcode server menggantikan seluruh set lama produk ini.
      batch.delete(
        'product_barcodes',
        where: 'product_id = ?',
        whereArgs: [item.id],
      );
      for (final code in item.barcodes) {
        batch.insert('product_barcodes', {
          'barcode': code,
          'product_id': item.id,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    await batch.commit(noResult: true);
  }

  /// Tombstone master dari /deleted/products — kunci kontrak = PLU.
  Future<void> deleteByPlu(List<String> plus) async {
    if (plus.isEmpty) return;
    final db = await _db.db;
    final batch = db.batch();
    for (final plu in plus) {
      batch.delete(
        'product_barcodes',
        where: 'product_id IN (SELECT product_id FROM products WHERE plu = ?)',
        whereArgs: [plu],
      );
      batch.delete('products', where: 'plu = ?', whereArgs: [plu]);
    }
    await batch.commit(noResult: true);
  }

  Future<int> count() async {
    final db = await _db.db;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM products');
    return ((rows.first['c']) as num).toInt();
  }

  /// Pencarian lokal dengan cakupan sama seperti server:
  /// nama / PLU / kode department / semua barcode.
  Future<List<Map<String, dynamic>>> searchByName(
    String keyword, {
    int limit = 20,
  }) async {
    final db = await _db.db;
    final like = '%$keyword%';
    return db.rawQuery(
      'SELECT p.* FROM products p '
      'WHERE p.name LIKE ? OR p.plu LIKE ? OR p.department_code LIKE ? '
      'OR EXISTS (SELECT 1 FROM product_barcodes b '
      'WHERE b.product_id = p.product_id AND b.barcode LIKE ?) '
      'LIMIT ?',
      [like, like, like, like, limit],
    );
  }
}

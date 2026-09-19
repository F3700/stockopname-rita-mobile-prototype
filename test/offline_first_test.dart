import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stockopname_rita_mobile/core/database/app_database.dart';
import 'package:stockopname_rita_mobile/core/database/product_repository.dart';
import 'package:stockopname_rita_mobile/core/database/so_repository.dart';
import 'package:stockopname_rita_mobile/core/network/dto.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<AppDatabase> openTestDb() async {
    final db = AppDatabase();
    final raw = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(
            version: 1,
            onCreate: (d, v) async {
              await d.execute(
                  'CREATE TABLE products(product_id INTEGER PRIMARY KEY, barcode TEXT NOT NULL UNIQUE, name TEXT NOT NULL, buy_price REAL NOT NULL, sell_price REAL NOT NULL, category_name TEXT NOT NULL, department_code TEXT NOT NULL, updated_at TEXT NOT NULL)');
              await d.execute(
                  'CREATE INDEX idx_products_barcode ON products(barcode)');
              await d.execute(
                  'CREATE TABLE so_items(local_id INTEGER PRIMARY KEY AUTOINCREMENT, rak_id INTEGER NOT NULL, rak_name TEXT NOT NULL, product_id INTEGER NOT NULL, barcode TEXT NOT NULL, product_name TEXT NOT NULL, quantity INTEGER NOT NULL CHECK (quantity >= 0), status TEXT NOT NULL DEFAULT \'PENDING\', attempts INTEGER NOT NULL DEFAULT 0, last_error TEXT, updated_locally TEXT NOT NULL, UNIQUE (rak_id, product_id))');
              await d.execute(
                  'CREATE TABLE racks(rak_id INTEGER PRIMARY KEY, name TEXT NOT NULL, inspector_id INTEGER NOT NULL)');
              await d.execute(
                  'CREATE TABLE sync_meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
            }));
    db.setTestDatabase(raw);
    return db;
  }

  test('barcode lookup memakai indexed query, barcode tetap String', () async {
    final db = await openTestDb();
    final repo = ProductRepository(db);
    await repo.upsertAll([
      ProductDto(
          id: 1,
          barcode: '0012345678905', // leading zero harus utuh
          name: 'Produk A',
          buyPrice: 9,
          sellPrice: 19,
          dateCreated: DateTime.utc(2026, 1, 1),
          dateUpdated: DateTime.utc(2026, 1, 2),
          categoryName: 'Cat',
          departmentCode: 'DPT'),
    ]);
    final found = await repo.findByBarcode('0012345678905');
    expect(found, isNotNull);
    expect(found!['barcode'], '0012345678905');
    expect(found['barcode'], isA<String>());
    expect(await repo.findByBarcode('999'), isNull);
  });

  test('duplikat: tambah vs ganti, 1 baris per produk per rak', () async {
    final db = await openTestDb();
    final so = SoRepository(db);
    var qty = await so.upsertScan(
        rakId: 1,
        rakName: 'RAK1',
        productId: 7,
        barcode: '123',
        productName: 'P',
        quantity: 3,
        mode: 'add');
    expect(qty, 3);
    qty = await so.upsertScan(
        rakId: 1,
        rakName: 'RAK1',
        productId: 7,
        barcode: '123',
        productName: 'P',
        quantity: 2,
        mode: 'add');
    expect(qty, 5);
    qty = await so.upsertScan(
        rakId: 1,
        rakName: 'RAK1',
        productId: 7,
        barcode: '123',
        productName: 'P',
        quantity: 2,
        mode: 'replace');
    expect(qty, 2);
    final rows = await so.listByRak(1);
    expect(rows.length, 1);
    expect(await so.countPending(), 1);
  });

  test('payload batch per rak sesuai kontrak backend', () async {
    final db = await openTestDb();
    final so = SoRepository(db);
    await so.upsertScan(
        rakId: 9,
        rakName: 'RAK9',
        productId: 1,
        barcode: '111',
        productName: 'A',
        quantity: 10,
        mode: 'add');
    await so.upsertScan(
        rakId: 9,
        rakName: 'RAK9',
        productId: 2,
        barcode: '222',
        productName: 'B',
        quantity: 4,
        mode: 'add');
    final pending = await so.pendingByRak(9);
    final items = so.toUploadItems(pending);
    expect(items.length, 2);
    final json = items.first.toJson();
    expect(json.keys.toSet(), {'product_id', 'rak_id', 'quantity'});
    expect(json['rak_id'], 9);
  });

  test('ProductDto parsing 1:1 dengan backend', () {
    final dto = ProductDto.fromJson({
      'id': 1,
      'barcode': '1234567890123',
      'name': 'Product A',
      'buy_price': 9.99,
      'sell_price': 19.99,
      'date_created': '2023-01-01T12:00:00Z',
      'date_updated': '2023-01-02T12:00:00Z',
      'category_name': 'Diary',
      'department_code': 'NSTL',
    });
    expect(dto.barcode, isA<String>());
    expect(dto.buyPrice, 9.99);
  });
}

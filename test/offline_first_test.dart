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

  /// Skema v4 harus sama dengan AppDatabase._createMasterTables/_createTxnTables.
  Future<AppDatabase> openTestDb() async {
    final db = AppDatabase();
    final raw = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (d, v) async {
          await d.execute(
            'CREATE TABLE products(product_id INTEGER PRIMARY KEY, plu TEXT NOT NULL, barcode TEXT NOT NULL DEFAULT \'\', name TEXT NOT NULL, buy_price REAL NOT NULL, sell_price REAL NOT NULL, department_code TEXT NOT NULL, updated_at TEXT NOT NULL)',
          );
          await d.execute(
            'CREATE UNIQUE INDEX idx_products_plu ON products(plu)',
          );
          await d.execute(
            'CREATE TABLE product_barcodes(barcode TEXT NOT NULL PRIMARY KEY, product_id INTEGER NOT NULL)',
          );
          await d.execute(
            'CREATE INDEX idx_product_barcodes_product ON product_barcodes(product_id)',
          );
          await d.execute(
            'CREATE TABLE so_items(local_id INTEGER PRIMARY KEY AUTOINCREMENT, rak_id INTEGER NOT NULL, rak_name TEXT NOT NULL, product_id INTEGER NOT NULL, plu TEXT NOT NULL DEFAULT \'\', barcode TEXT NOT NULL, product_name TEXT NOT NULL, quantity INTEGER NOT NULL CHECK (quantity >= 0), status TEXT NOT NULL DEFAULT \'PENDING\', attempts INTEGER NOT NULL DEFAULT 0, last_error TEXT, updated_locally TEXT NOT NULL, UNIQUE (rak_id, product_id))',
          );
          await d.execute('CREATE INDEX idx_so_items_rak ON so_items(rak_id)');
          await d.execute(
            'CREATE INDEX idx_so_items_status ON so_items(status)',
          );
          await d.execute(
            'CREATE TABLE racks(rak_id INTEGER PRIMARY KEY, name TEXT NOT NULL, inspector_id INTEGER NOT NULL, done INTEGER NOT NULL DEFAULT 0)',
          );
          await d.execute(
            'CREATE TABLE sessions(id INTEGER PRIMARY KEY AUTOINCREMENT, sesi_code TEXT NOT NULL, coor_code TEXT NOT NULL, inspector_code TEXT NOT NULL, inspector_id INTEGER NOT NULL, join_via TEXT NOT NULL DEFAULT \'manual\', status TEXT NOT NULL DEFAULT \'ACTIVE\', created_at TEXT NOT NULL, finished_at TEXT)',
          );
          await d.execute(
            'CREATE TABLE sync_meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
        },
      ),
    );
    db.setTestDatabase(raw);
    return db;
  }

  ProductDto product({
    int id = 1,
    String plu = '100251',
    List<String> barcodes = const ['8991001010016'],
  }) {
    return ProductDto(
      id: id,
      plu: plu,
      barcode: barcodes.isEmpty ? '' : barcodes.first,
      barcodes: barcodes,
      name: 'Sari Roti',
      buyPrice: 14500,
      sellPrice: 17200,
      dateCreated: DateTime.utc(2026, 1, 1),
      dateUpdated: DateTime.utc(2026, 9, 10),
      departmentCode: '1138',
    );
  }

  test('lookup barcode memakai index, barcode sekunder ikut ketemu', () async {
    final db = await openTestDb();
    final repo = ProductRepository(db);
    await repo.upsertAll([
      product(barcodes: const ['0012345678905', '8991001010016']),
    ]);

    final primary = await repo.findByBarcode('0012345678905');
    expect(primary, isNotNull);
    expect(primary!['barcode'], '0012345678905'); // leading zero harus utuh
    expect(primary['barcode'], isA<String>());

    final secondary = await repo.findByBarcode('8991001010016');
    expect(secondary, isNotNull);
    expect(secondary!['plu'], '100251');

    expect(await repo.findByBarcode('999'), isNull);
  });

  test('hapus master memakai PLU (kontrak tombstones)', () async {
    final db = await openTestDb();
    final repo = ProductRepository(db);
    await repo.upsertAll([
      product(id: 1, plu: '100251'),
      product(id: 2, plu: '100252', barcodes: const ['1002525550018']),
    ]);
    expect(await repo.count(), 2);

    await repo.deleteByPlu(['100251']);

    expect(await repo.count(), 1);
    expect(await repo.findByBarcode('0012345678905'), isNull);
    expect(await repo.findByBarcode('1002525550018'), isNotNull);
  });

  test('duplikat: tambah vs ganti, 1 baris per produk per rak', () async {
    final db = await openTestDb();
    final so = SoRepository(db);
    var qty = await so.upsertScan(
      rakId: 1,
      rakName: 'RAK1',
      productId: 7,
      plu: '100251',
      barcode: '123',
      productName: 'P',
      quantity: 3,
      mode: 'add',
    );
    expect(qty, 3);
    qty = await so.upsertScan(
      rakId: 1,
      rakName: 'RAK1',
      productId: 7,
      plu: '100251',
      barcode: '123',
      productName: 'P',
      quantity: 2,
      mode: 'add',
    );
    expect(qty, 5);
    qty = await so.upsertScan(
      rakId: 1,
      rakName: 'RAK1',
      productId: 7,
      plu: '100251',
      barcode: '123',
      productName: 'P',
      quantity: 2,
      mode: 'replace',
    );
    expect(qty, 2);
    final rows = await so.listByRak(1);
    expect(rows.length, 1);
    expect(rows.first['plu'], '100251');
    expect(await so.countPending(), 1);
  });

  test('payload batch per rak sesuai kontrak backend (plu/barcode)', () async {
    final db = await openTestDb();
    final so = SoRepository(db);
    await so.upsertScan(
      rakId: 9,
      rakName: 'RAK9',
      productId: 1,
      plu: '100251',
      barcode: '8991001010016',
      productName: 'A',
      quantity: 10,
      mode: 'add',
    );
    await so.upsertScan(
      rakId: 9,
      rakName: 'RAK9',
      productId: 2,
      plu: '100252',
      barcode: '1002525550018',
      productName: 'B',
      quantity: 4,
      mode: 'add',
    );
    final pending = await so.pendingByRak(9);
    final items = so.toUploadItems(pending);
    expect(items.length, 2);
    final json = items.first.toJson();
    expect(json.keys.toSet(), {'rak_id', 'quantity', 'plu', 'barcode'});
    expect(json['rak_id'], 9);
    expect(json['plu'], '100251');
    expect(json['barcode'], '8991001010016');
  });

  test('ProductDto parsing 1:1 dengan backend (plu + barcodes)', () {
    final dto = ProductDto.fromJson({
      'id': 1,
      'plu': '100251',
      'barcode': '1234567890123',
      'barcodes': ['1234567890123', '8991001010016'],
      'name': 'Product A',
      'buy_price': 9.99,
      'sell_price': 19.99,
      'date_created': '2023-01-01T12:00:00Z',
      'date_updated': '2023-01-02T12:00:00Z',
      'department_code': 'NSTL',
    });
    expect(dto.barcode, isA<String>());
    expect(dto.plu, '100251');
    expect(dto.barcodes, hasLength(2));
    expect(dto.buyPrice, 9.99);
  });

  test('DeletedProductDto memakai plu, bukan id', () {
    final dto = DeletedProductDto.fromJson({'plu': '100251'});
    expect(dto.plu, '100251');
  });
}

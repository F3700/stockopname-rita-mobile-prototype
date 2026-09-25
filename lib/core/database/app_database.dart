import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

/// SQLite offline-first. Raw SQL hanya di sini + repository, tidak di widget.
///
/// Pemisahan konseptual:
/// - MASTER (produk + barcode + sync_meta): cache yang boleh dihapus dan
///   diunduh ulang dari server kapan saja.
/// - TRANSAKSI (so_items + racks + sessions): hasil kerja inspector; setelah
///   rilis, migrasi berikutnya WAJIB mempertahankan tabel-tabel ini.
class AppDatabase {
  Database? _db;

  Future<Database> get db async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'rita_stockopname.db');
    _db = await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await _createMasterTables(db);
        await _createTxnTables(db);
      },
      onUpgrade: (db, oldV, newV) async {
        await _onUpgrade(db, oldV, newV);
      },
    );
    return _db!;
  }

  /// Untuk unit test dengan sqflite_common_ffi.
  void setTestDatabase(Database database) => _db = database;

  /// v3 -> v4: kontrak master berubah total (plu + multi-barcode, tanpa
  /// category_name) dan app masih pra-rilis.
  /// Migrasi destruktif terakhir yang disengaja: semua tabel dibangun ulang,
  /// lalu `last_product_sync` kosong memaksa full resync master saat online.
  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 4) {
      await _dropAll(db);
      await _createMasterTables(db);
      await _createTxnTables(db);
    }
  }

  Future<void> _dropAll(Database db) async {
    for (final table in [
      'products',
      'product_barcodes',
      'sync_meta',
      'so_items',
      'racks',
      'sessions',
    ]) {
      await db.execute('DROP TABLE IF EXISTS $table');
    }
  }

  /// MASTER — cache dari server; aman dihapus & disinkron ulang.
  Future<void> _createMasterTables(Database db) async {
    await db.execute('''
      CREATE TABLE products(
        product_id INTEGER PRIMARY KEY,
        plu TEXT NOT NULL,
        barcode TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL,
        buy_price REAL NOT NULL,
        sell_price REAL NOT NULL,
        department_code TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX idx_products_plu ON products(plu)');

    // 1 produk -> N barcode. Lookup scan memakai PK `barcode` (indexed).
    await db.execute('''
      CREATE TABLE product_barcodes(
        barcode TEXT NOT NULL PRIMARY KEY,
        product_id INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_product_barcodes_product ON product_barcodes(product_id)',
    );

    await db.execute('''
      CREATE TABLE sync_meta(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  /// TRANSAKSI — hasil kerja inspector; jangan di-drop setelah rilis.
  Future<void> _createTxnTables(Database db) async {
    await db.execute('''
      CREATE TABLE so_items(
        local_id INTEGER PRIMARY KEY AUTOINCREMENT,
        rak_id INTEGER NOT NULL,
        rak_name TEXT NOT NULL,
        product_id INTEGER NOT NULL,
        plu TEXT NOT NULL DEFAULT '',
        barcode TEXT NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL CHECK (quantity >= 0),
        status TEXT NOT NULL DEFAULT 'PENDING',
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        updated_locally TEXT NOT NULL,
        UNIQUE (rak_id, product_id)
      )
    ''');
    await db.execute('CREATE INDEX idx_so_items_rak ON so_items(rak_id)');
    await db.execute('CREATE INDEX idx_so_items_status ON so_items(status)');

    await db.execute('''
      CREATE TABLE racks(
        rak_id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        inspector_id INTEGER NOT NULL,
        done INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sesi_code TEXT NOT NULL,
        coor_code TEXT NOT NULL,
        inspector_code TEXT NOT NULL,
        inspector_id INTEGER NOT NULL,
        join_via TEXT NOT NULL DEFAULT 'manual',
        status TEXT NOT NULL DEFAULT 'ACTIVE',
        created_at TEXT NOT NULL,
        finished_at TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_sessions_status ON sessions(status)');
  }
}

// Status sync lokal. SYNCED hanya setelah server 2xx.
class SoStatus {
  static const pending = 'PENDING';
  static const syncing = 'SYNCING';
  static const synced = 'SYNCED';
  static const failed = 'FAILED';
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

/// SQLite offline-first. Raw SQL hanya di sini + repository, tidak di widget.
class AppDatabase {
  Database? _db;

  Future<Database> get db async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'rita_stockopname.db');
    _db = await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await _onCreate(db, version);
        await _migrateToV2(db);
        await _migrateToV3(db);
      },
      onUpgrade: (db, oldV, newV) async {
        await _onUpgrade(db, oldV, newV);
      },
    );
    return _db!;
  }

  /// Untuk unit test dengan sqflite_common_ffi.
  void setTestDatabase(Database database) => _db = database;

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products(
        product_id INTEGER PRIMARY KEY,
        barcode TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        buy_price REAL NOT NULL,
        sell_price REAL NOT NULL,
        category_name TEXT NOT NULL,
        department_code TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_products_barcode ON products(barcode)');

    await db.execute('''
      CREATE TABLE so_items(
        local_id INTEGER PRIMARY KEY AUTOINCREMENT,
        rak_id INTEGER NOT NULL,
        rak_name TEXT NOT NULL,
        product_id INTEGER NOT NULL,
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
        inspector_id INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_meta(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // Migrasi harus aditif — jangan pernah DROP so_items berisi data offline.
  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) await _migrateToV2(db);
    if (oldV < 3) await _migrateToV3(db);
  }

  /// v2: riwayat sesi + flag selesai per rak (lokal).
  Future<void> _migrateToV2(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sesi_code TEXT NOT NULL,
        coor_code TEXT NOT NULL,
        inspector_code TEXT NOT NULL,
        inspector_id INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'ACTIVE',
        created_at TEXT NOT NULL,
        finished_at TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sessions_status ON sessions(status)');
    try {
      await db.execute(
          'ALTER TABLE racks ADD COLUMN done INTEGER NOT NULL DEFAULT 0');
    } catch (_) {
      // Kolom sudah ada (fresh install via onCreate + migrate) — aman abaikan.
    }
  }

  /// v3: penanda asal join sesi — 'manual' vs 'qr'. Flow manual tidak berubah
  /// (default 'manual'), flow QR mengisi 'qr'. Murni aditif.
  Future<void> _migrateToV3(Database db) async {
    try {
      await db.execute(
          "ALTER TABLE sessions ADD COLUMN join_via TEXT NOT NULL DEFAULT 'manual'");
    } catch (_) {
      // Kolom sudah ada (fresh install via onCreate + migrate) — aman abaikan.
    }
  }
}

// Status sync lokal. SYNCED hanya setelah server 2xx.
class SoStatus {
  static const pending = 'PENDING';
  static const syncing = 'SYNCING';
  static const synced = 'SYNCED';
  static const failed = 'FAILED';
}

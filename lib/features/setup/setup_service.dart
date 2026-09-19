import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/database/session_repository.dart';
import '../../core/error/app_error.dart';
import '../../core/network/api_client.dart';
import '../../core/network/dto.dart';

/// Sesi aktif tanpa login: hasil POST inspectors/racks, disimpan di memori + SQLite racks.
class ActiveSession {
  const ActiveSession({
    required this.dbId,
    required this.sesiCode,
    required this.coorCode,
    required this.inspectorCode,
    required this.inspectorId,
    required this.currentRakId,
    required this.currentRakName,
  });

  /// id baris tabel sessions lokal.
  final int dbId;
  final String sesiCode;
  final String coorCode;
  final String inspectorCode;
  final int inspectorId;
  final int currentRakId;
  final String currentRakName;

  ActiveSession copyWith({int? currentRakId, String? currentRakName}) =>
      ActiveSession(
        dbId: dbId,
        sesiCode: sesiCode,
        coorCode: coorCode,
        inspectorCode: inspectorCode,
        inspectorId: inspectorId,
        currentRakId: currentRakId ?? this.currentRakId,
        currentRakName: currentRakName ?? this.currentRakName,
      );
}

final activeSessionProvider =
    NotifierProvider<ActiveSessionNotifier, ActiveSession?>(() {
  return ActiveSessionNotifier();
});

class ActiveSessionNotifier extends Notifier<ActiveSession?> {
  @override
  ActiveSession? build() => null;

  void set(ActiveSession? value) => state = value;
}

final setupServiceProvider = Provider<SetupService>((ref) {
  return SetupService(
    api: ref.watch(apiClientProvider),
    db: ref.watch(databaseProvider),
    sessions: ref.watch(sessionRepositoryProvider),
  );
});

class SetupService {
  SetupService({required this.api, required this.db, required this.sessions});
  final ApiClient api;
  final AppDatabase db;
  final SessionRepository sessions;

  Future<ActiveSession> setup({
    required String sesiCode,
    required String coorCode,
    required String inspectorCode,
    required List<String> rakNames,
    String? extraRak,
  }) async {
    if (sesiCode.isEmpty ||
        coorCode.isEmpty ||
        inspectorCode.isEmpty ||
        rakNames.isEmpty) {
      throw const AppFailure(AppMessages.setupIncomplete);
    }
    final result = await api.createInspector(
      sesiCode: sesiCode,
      coorCode: coorCode,
      inspectorCode: inspectorCode,
      rak: rakNames,
    );
    final database = await db.db;
    for (final r in result.racks) {
      await database.insert(
        'racks',
        {
          'rak_id': r.id,
          'name': r.name,
          'inspector_id': result.inspectorId,
          'done': 0
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    var currentRak = result.racks.first;
    if (extraRak != null && extraRak.isNotEmpty) {
      final newId =
          await api.createRack(inspectorId: result.inspectorId, rakName: extraRak);
      await database.insert(
        'racks',
        {
          'rak_id': newId,
          'name': extraRak,
          'inspector_id': result.inspectorId,
          'done': 0
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      currentRak = RackDto(id: newId, name: extraRak);
    }
    final dbId = await sessions.create(
      sesiCode: sesiCode,
      coorCode: coorCode,
      inspectorCode: inspectorCode,
      inspectorId: result.inspectorId,
    );
    return ActiveSession(
      dbId: dbId,
      sesiCode: sesiCode,
      coorCode: coorCode,
      inspectorCode: inspectorCode,
      inspectorId: result.inspectorId,
      currentRakId: currentRak.id,
      currentRakName: currentRak.name,
    );
  }

  Future<List<RackDto>> racksOf(int inspectorId) =>
      api.fetchRacks(inspectorId: inspectorId);

  /// Tambah rak ke sesi berjalan (tombol "Tambah Rak").
  Future<RackDto> addRak({
    required int inspectorId,
    required String rakName,
  }) async {
    final name = rakName.trim();
    if (name.isEmpty) {
      throw const AppFailure('Nama rak tidak boleh kosong.');
    }
    final newId =
        await api.createRack(inspectorId: inspectorId, rakName: name);
    await sessions.addLocalRak(
        rakId: newId, name: name, inspectorId: inspectorId);
    return RackDto(id: newId, name: name);
  }

  /// Selesai sesi: tandai DONE + semua rak DONE (lokal saja, tanpa upload).
  Future<void> finishSession(ActiveSession session) async {
    await sessions.markRaksDoneByInspector(session.inspectorId);
    await sessions.markDone(session.dbId);
  }
}

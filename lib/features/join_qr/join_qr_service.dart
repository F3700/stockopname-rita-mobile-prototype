import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/database/session_repository.dart';
import 'package:dio/dio.dart';

import '../../core/error/app_error.dart';
import '../../core/network/qr_join_api.dart';
import '../../core/qr/coor_qr.dart';
import '../setup/setup_service.dart';

final joinQrServiceProvider = Provider<JoinQrService>((ref) {
  return JoinQrService(
    api: ref.watch(qrJoinApiClientProvider),
    db: ref.watch(databaseProvider),
    sessions: ref.watch(sessionRepositoryProvider),
  );
});

/// Join via QR coordinator — endpoint BARU saja, flow manual tidak tersentuh.
/// Gerbang online/fresh dipanggil UI sebelum masuk sini (sama seperti manual).
class JoinQrService {
  JoinQrService({required this.api, required this.db, required this.sessions});
  final QrJoinApi api;
  final AppDatabase db;
  final SessionRepository sessions;

  Future<ActiveSession> joinViaQr({
    required String coordinatorQr,
    required String inspectorCode,
    required List<String> rakNames,
    String sessionCode = '',
  }) async {
    final qr = coordinatorQr.trim().toUpperCase();
    final coorId = CoorQr.tryParseCoorQr(qr);
    if (coorId == null) {
      throw const AppFailure(
        'QR tidak valid. Contoh format: RITA-COOR-12.',
      );
    }
    if (inspectorCode.trim().isEmpty || rakNames.isEmpty) {
      throw const AppFailure(
        'Lengkapi kode inspector dan minimal 1 rak.',
      );
    }
    final result = await api.joinByCoordinatorQr(
      coordinatorQr: qr,
      inspectorCode: inspectorCode.trim(),
      rak: rakNames,
    );
    if (result.racks.isEmpty) {
      throw const AppFailure('Respons join QR tidak membawa data rak.');
    }
    final database = await db.db;
    for (final r in result.racks) {
      await database.insert(
        'racks',
        {
          'rak_id': r.id,
          'name': r.name,
          'inspector_id': result.inspectorId,
          'done': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    // Kolom lokal NOT NULL: pakai sesi code asli bila backend sudah
    // mengirimnya, fallback sintetis agar traceable bila belum.
    final sesiCode =
        sessionCode.trim().isEmpty ? 'QR-COOR-$coorId' : sessionCode.trim();
    final dbId = await sessions.create(
      sesiCode: sesiCode,
      coorCode: qr,
      inspectorCode: inspectorCode.trim(),
      inspectorId: result.inspectorId,
      joinVia: 'qr',
    );
    final currentRak = result.racks.first;
    return ActiveSession(
      dbId: dbId,
      sesiCode: sesiCode,
      coorCode: qr,
      inspectorCode: inspectorCode.trim(),
      inspectorId: result.inspectorId,
      currentRakId: currentRak.id,
      currentRakName: currentRak.name,
    );
  }

  Future<CoordinatorPreview> preview(
    int coorId, {
    CancelToken? cancelToken,
  }) =>
      api.fetchCoordinatorPreview(coorId, cancelToken: cancelToken);
}

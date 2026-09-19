import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/so_repository.dart';
import '../../core/error/app_error.dart';
import '../../core/logging/app_logger.dart';
import '../../core/network/api_client.dart';

final uploadServiceProvider = Provider<UploadService>((ref) {
  return UploadService(
    api: ref.watch(apiClientProvider),
    so: ref.watch(soRepositoryProvider),
  );
});

final pendingCountProvider = FutureProvider<int>((ref) async {
  final so = ref.watch(soRepositoryProvider);
  return so.countPending();
});

/// Upload batch per rak. Sukses 2xx → SYNCED (rak selesai). Gagal → FAILED, data aman.
class UploadService {
  UploadService({required this.api, required this.so});
  final ApiClient api;
  final SoRepository so;

  Future<void> uploadRak(int rakId) async {
    final pending = await so.pendingByRak(rakId);
    if (pending.isEmpty) return;
    final items = so.toUploadItems(pending);
    await so.markSyncing(rakId);
    try {
      await api.uploadByRack(rakId: rakId, items: items);
      await so.markSynced(rakId);
    } on AppFailure catch (e, st) {
      appLogger.e('upload rak $rakId gagal', error: e, stackTrace: st);
      await so.markFailed(rakId, e.userMessage);
      rethrow;
    }
  }
}

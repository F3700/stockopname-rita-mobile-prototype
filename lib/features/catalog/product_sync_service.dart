import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/product_repository.dart';
import '../../core/database/sync_meta_repository.dart';
import '../../core/error/app_error.dart';
import '../../core/logging/app_logger.dart';
import '../../core/network/api_client.dart';

final productSyncServiceProvider = Provider<ProductSyncService>((ref) {
  return ProductSyncService(
    api: ref.watch(apiClientProvider),
    products: ref.watch(productRepositoryProvider),
    meta: ref.watch(syncMetaRepositoryProvider),
  );
});

final productSyncStateProvider =
    NotifierProvider<ProductSyncStateNotifier, ProductSyncState>(() {
      return ProductSyncStateNotifier();
    });

class ProductSyncStateNotifier extends Notifier<ProductSyncState> {
  @override
  ProductSyncState build() => const ProductSyncState.idle();

  void set(ProductSyncState value) => state = value;
}

class ProductSyncState {
  const ProductSyncState.idle()
    : running = false,
      message = 'Belum disinkronkan',
      progress = 0;
  const ProductSyncState({
    required this.running,
    required this.message,
    required this.progress,
  });

  final bool running;
  final String message;
  final double progress;
}

/// Download incremental: /products/sync?updated_after + /deleted/products.
class ProductSyncService {
  ProductSyncService({
    required this.api,
    required this.products,
    required this.meta,
  });

  final ApiClient api;
  final ProductRepository products;
  final SyncMetaRepository meta;

  static const int pageSize = 1500;

  Future<void> run(void Function(ProductSyncState) onProgress) async {
    onProgress(
      const ProductSyncState(
        running: true,
        message: 'Sinkronisasi produk...',
        progress: 0,
      ),
    );
    try {
      final last = await meta.getLastProductSync();
      if (last == null) {
        await _initial(onProgress);
      } else {
        await _incremental(onProgress, last);
      }
      final count = await products.count();
      onProgress(
        ProductSyncState(
          running: false,
          message: 'Master lokal: $count produk ✓',
          progress: 1,
        ),
      );
    } on AppFailure catch (e) {
      appLogger.w('sync failed: $e');
      onProgress(
        const ProductSyncState(
          running: false,
          message: AppMessages.syncFailedKept,
          progress: 0,
        ),
      );
      rethrow;
    }
  }

  Future<void> _initial(void Function(ProductSyncState) onProgress) async {
    var page = 1;
    while (true) {
      final res = await api.fetchProducts(page: page, limit: pageSize);
      await products.upsertAll(res.items);
      onProgress(
        ProductSyncState(
          running: true,
          message: 'Unduh master: halaman $page/${res.totalPages}',
          progress: page / (res.totalPages == 0 ? 1 : res.totalPages),
        ),
      );
      if (page >= res.totalPages || res.items.isEmpty) break;
      page++;
    }
    await meta.setLastProductSync(DateTime.now().toUtc());
  }

  Future<void> _incremental(
    void Function(ProductSyncState) onProgress,
    DateTime since,
  ) async {
    var page = 1;
    while (true) {
      final res = await api.syncProducts(
        page: page,
        limit: pageSize,
        updatedAfter: since,
      );
      await products.upsertAll(res.items);
      if (page >= res.totalPages || res.items.isEmpty) break;
      page++;
      onProgress(
        ProductSyncState(
          running: true,
          message: 'Sync halaman $page...',
          progress: 0.5,
        ),
      );
    }
    final deleted = await api.fetchDeletedProducts(updatedAfter: since);
    await products.deleteByPlu(
      deleted.map((e) => e.plu).where((p) => p.isNotEmpty).toList(),
    );
    await meta.setLastProductSync(DateTime.now().toUtc());
  }
}

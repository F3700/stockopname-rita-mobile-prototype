import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connectivity/connectivity_providers.dart';
import '../../core/database/sync_meta_repository.dart';
import '../../core/ui/rita_dialog.dart';
import 'product_sync_service.dart';

/// Batas umur sync agar master dianggap segar. Satu tempat, mudah diubah.
const maxSyncAge = Duration(minutes: 15);

/// Gerbang ringan: WAJIB online saja (tanpa cek freshness).
/// false = dialog penolakan tampil, pengguna tetap di layar.
Future<bool> requireOnline(BuildContext context, ProviderContainer container,
    String action) async {
  if (container.read(isOnlineProvider)) return true;
  if (!context.mounted) return false;
  await showRitaDialog<void>(
    context: context,
    builder: (ctx) => RitaAlert(
      title: const Text('Wajib online'),
      content: Text(
          'Tidak ada koneksi internet. $action membutuhkan koneksi.'),
      actions: [
        FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK')),
      ],
    ),
  );
  return false;
}

/// Gerbang gabungan: WAJIB online + master harus segar (< 15 mnt).
/// false = tolak, pengguna tetap di layar.
Future<bool> ensureOnlineAndFresh(BuildContext context,
    ProviderContainer container, String action) async {
  if (!container.read(isOnlineProvider)) {
    if (!context.mounted) return false;
    await showRitaDialog<void>(
      context: context,
      builder: (ctx) => RitaAlert(
        title: const Text('Wajib online'),
        content: Text(
            'Tidak ada koneksi internet. $action membutuhkan koneksi.'),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK')),
        ],
      ),
    );
    return false;
  }
  final last = await container
      .read(syncMetaRepositoryProvider)
      .getLastProductSync();
  if (!context.mounted) return false;
  final fresh = last != null &&
      DateTime.now().difference(last.toLocal()) < maxSyncAge;
  if (fresh) return true;
  return ensureMasterSynced(context, container);
}

/// Gerbang wajib: sync master produk sampai tuntas SEBELUM masuk sesi.
/// true = boleh lanjut (sudah sync, atau user memilih lanjut offline
/// setelah gagal). Dialog tidak bisa di-dismiss paksa (back diblokir).
Future<bool> ensureMasterSynced(
    BuildContext context, ProviderContainer container) async {
  final service = container.read(productSyncServiceProvider);
  final notifier = container.read(productSyncStateProvider.notifier);
  var done = false;
  BuildContext? dlgCtx;

  void start() {
    done = false;
    notifier.set(const ProductSyncState(
        running: true,
        message: 'Sinkronisasi master produk...',
        progress: 0));
    service.run((s) {
      try {
        notifier.set(s);
      } catch (_) {}
    }).then((_) {
      done = true;
      if (dlgCtx?.mounted == true) Navigator.of(dlgCtx!).pop(true);
    }).catchError((_) {
      // State gagal sudah dipasang service — dialog menampilkan aksi.
    });
  }

  start();
  final res = await showRitaDialog<bool>(
    context: context,
    barrierDismissible: false,
    force: true,
    builder: (ctx) {
      dlgCtx = ctx;
      if (done) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) {
              if (ctx.mounted) Navigator.of(ctx).pop(true);
            });
      }
      return PopScope(
        canPop: false,
        child: RitaAlert(
          title: const Text('Sinkronisasi master'),
          content: StatefulBuilder(
            builder: (ctx, setD) => Consumer(
              builder: (_, ref, __) {
                final st = ref.watch(productSyncStateProvider);
                if (!st.running && done) return Text(st.message);
                if (!st.running) {
                  // Gagal — tawarkan coba lagi atau lanjut offline.
                  // Wrap agar tombol turun baris di layar sempit.
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(st.message),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(ctx).pop(false),
                            child: const Text('Lanjut offline'),
                          ),
                          FilledButton(
                            onPressed: () {
                              start();
                              setD(() {});
                            },
                            child: const Text('Coba lagi'),
                          ),
                        ],
                      ),
                    ],
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                        value: st.progress <= 0 ? null : st.progress),
                    const SizedBox(height: 12),
                    Text(st.message),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );
  if (res == true) container.invalidate(lastSyncProvider);
  return res != null;
}

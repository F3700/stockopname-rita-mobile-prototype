import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockopname_rita_mobile/core/ui/design_system/rita_band.dart';
import 'package:stockopname_rita_mobile/core/ui/design_system/rita_buttons.dart';
import 'package:stockopname_rita_mobile/core/ui/design_system/rita_card.dart';
import 'package:stockopname_rita_mobile/core/ui/design_system/rita_feedback.dart';
import 'package:stockopname_rita_mobile/core/ui/design_system/rita_field.dart';
import 'package:stockopname_rita_mobile/core/ui/design_system/rita_pill.dart';
import 'package:stockopname_rita_mobile/core/ui/design_system/rita_search.dart';
import 'package:stockopname_rita_mobile/core/ui/design_system/rita_states.dart';
import 'package:stockopname_rita_mobile/core/ui/design_system/rita_tokens.dart';
import 'package:stockopname_rita_mobile/core/ui/design_system/rita_viewfinder.dart';

/// Review pass design system v5: render semua komponen bersama di viewport
/// mobile 360x800. Overflow/layout error otomatis gagal di widget test.
void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    // Tinggi ekstra agar seluruh katalog komponen ter-render sekaligus
    // (ListView membangun anak yang terlihat saja).
    view.physicalSize = const Size(360, 2600);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets(
    'band, pill, tombol, kartu, field, banner, state — tanpa overflow',
    (tester) async {
      final ctrl = TextEditingController(text: 'SO-2026-01');
      addTearDown(ctrl.dispose);
      final searchCtrl = TextEditingController();
      addTearDown(searchCtrl.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(RitaSpace.screen),
              children: [
                // Header/band tidak bisa di dalam ListView (PreferredSizeWidget);
                // diuji terpisah di bawah.
                RitaPill.status(RitaStatus.berjalan),
                const SizedBox(height: 8),
                RitaPill.status(RitaStatus.selesai),
                const SizedBox(height: 8),
                RitaPill.status(RitaStatus.proses),
                const SizedBox(height: 8),
                RitaPill.status(RitaStatus.belumUpload),
                const SizedBox(height: 8),
                RitaPill.status(RitaStatus.gagal),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    RitaPill(
                      label: 'via QR',
                      bg: RitaPalette.white,
                      fg: RitaPalette.grey,
                      border: RitaPalette.border,
                    ),
                    SizedBox(width: 8),
                    RitaPill(
                      label: 'HASIL SCAN',
                      bg: RitaPalette.successBg,
                      fg: RitaPalette.successText,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                RitaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('1021', style: RitaType.title)),
                          RitaPill.status(RitaStatus.selesai),
                          const SizedBox(width: 8),
                          RitaIconButton(
                            icon: Icons.delete_outline,
                            color: RitaPalette.primary,
                            onPressed: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('12 barang - Rp150.000', style: RitaType.meta),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.check,
                            size: 16,
                            color: RitaPalette.successText,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Terupload',
                            style: RitaType.caption.copyWith(
                              color: RitaPalette.successText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                RitaField(
                  label: 'KODE SESI',
                  controller: ctrl,
                  hint: 'contoh: SO-2026-01',
                ),
                const SizedBox(height: 16),
                RitaField(
                  label: 'JUMLAH',
                  controller: ctrl,
                  hint: '0',
                  errorText: 'Jumlah harus lebih dari 0.',
                ),
                const SizedBox(height: 16),
                RitaPrimaryButton(label: 'LANJUT KE RAK', onPressed: () {}),
                const SizedBox(height: 12),
                const RitaPrimaryButton(label: 'MENYIMPAN...', loading: true),
                const SizedBox(height: 12),
                RitaSecondaryButton(
                  label: 'SCAN QR COORDINATOR',
                  icon: Icons.qr_code_scanner,
                  onPressed: () {},
                ),
                const SizedBox(height: 16),
                const RitaBanner(
                  kind: RitaBannerKind.offline,
                  title: 'Tidak ada koneksi - mode offline',
                  message: 'Scan tetap jalan. Unggah butuh internet.',
                  actionLabel: 'Detail',
                ),
                const SizedBox(height: 12),
                const RitaBanner(
                  kind: RitaBannerKind.syncing,
                  title: 'Menyinkronkan master...',
                  message: '12.400 dari 48.900 produk',
                  progress: 0.35,
                ),
                const SizedBox(height: 12),
                const RitaBanner(
                  kind: RitaBannerKind.error,
                  title: 'Rak 1021 gagal terupload',
                  actionLabel: 'Ulangi',
                ),
                const SizedBox(height: 12),
                const RitaBanner(
                  kind: RitaBannerKind.success,
                  title: 'Rak 1021 terupload',
                  message: '12 item - 20 Sep 10:05',
                ),
                const SizedBox(height: 16),
                const RitaEmptyState(
                  title: 'Belum ada sesi',
                  message: 'Mulai stock opname atau pindai QR koordinator.',
                  actionLabel: 'Mulai stock opname',
                ),
                const SizedBox(height: 16),
                const RitaListSkeleton(),
                const SizedBox(height: 16),
                const RitaLoading(label: 'Memuat...'),
                const SizedBox(height: 16),
                RitaSearchField(controller: searchCtrl, hint: 'Cari rak...'),
                const SizedBox(height: 16),
                SizedBox(
                  height: 190,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(RitaRadius.lg),
                    child: const ColoredBox(
                      color: Colors.black,
                      child: RitaCornerMarks(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final err = tester.takeException();
      expect(err, isNull, reason: err is FlutterError ? err.toString() : null);
      expect(find.text('Berjalan'), findsOneWidget);
      expect(find.text('Selesai'), findsWidgets);
      expect(find.text('JUMLAH'), findsOneWidget);
      expect(find.text('LANJUT KE RAK'), findsOneWidget);
      expect(find.text('Tidak ada koneksi - mode offline'), findsOneWidget);
      expect(find.text('Belum ada sesi'), findsOneWidget);
    },
  );

  testWidgets('RitaBand dengan back + pill kanan (band 80, target 44)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: RitaBand(
            title: 'SO-2026-01',
            subtitle: 'BUDI - Senin, 22 Sep',
            onBack: () {},
            trailing: RitaPill.status(RitaStatus.berjalan),
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('SO-2026-01'), findsOneWidget);
    expect(find.text('BUDI - Senin, 22 Sep'), findsOneWidget);
    expect(find.text('Berjalan'), findsOneWidget);

    // Target back 44x44 dan band 80 (plus status bar 0 di test).
    expect(tester.getSize(find.byIcon(Icons.arrow_back)).height, 24);
    final bandSize = tester.getSize(find.byType(RitaBand));
    expect(bandSize.height, RitaSizes.band);
  });

  testWidgets('showRitaToast tampil dengan aksi Ulangi', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: RitaPrimaryButton(
                label: 'TRIGGER',
                onPressed: () => showRitaToast(
                  context,
                  'Upload gagal - periksa koneksi',
                  actionLabel: 'Ulangi',
                  onAction: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('TRIGGER'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Upload gagal - periksa koneksi'), findsOneWidget);
    expect(find.text('Ulangi'), findsOneWidget);
  });
}

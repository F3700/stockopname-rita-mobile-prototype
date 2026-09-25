import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/connectivity/connectivity_providers.dart';
import '../../core/database/product_repository.dart';
import '../../core/database/session_repository.dart';
import '../../core/database/so_repository.dart';
import '../../core/error/app_error.dart';
import '../../core/scanner/barcode_scanner_service.dart';
import '../../core/ui/design_system/rita_band.dart';
import '../../core/ui/design_system/rita_buttons.dart';
import '../../core/ui/design_system/rita_card.dart';
import '../../core/ui/design_system/rita_feedback.dart';
import '../../core/ui/design_system/rita_pill.dart';
import '../../core/ui/design_system/rita_search.dart';
import '../../core/ui/design_system/rita_states.dart';
import '../../core/ui/design_system/rita_tokens.dart';
import '../../core/ui/design_system/rita_viewfinder.dart';
import '../../core/ui/rita_dialog.dart';
import '../racks/rack_providers.dart';
import '../setup/setup_service.dart';
import '../upload/upload_service.dart';
import 'product_detail_screen.dart';

/// Item hasil scan satu rak. Invalidate tiap ada simpan/ubah.
final rakItemsProvider = FutureProvider.family<List<Map<String, dynamic>>, int>(
  (ref, rakId) {
    return ref.watch(soRepositoryProvider).listByRak(rakId);
  },
);

/// Scan per rak (v5): kamera viewfinder + PLU manual + daftar hasil + SELESAI.
class RackScanScreen extends ConsumerStatefulWidget {
  const RackScanScreen({super.key, required this.rakId, required this.rakName});
  final int rakId;
  final String rakName;

  @override
  ConsumerState<RackScanScreen> createState() => _RackScanScreenState();
}

class _RackScanScreenState extends ConsumerState<RackScanScreen>
    with WidgetsBindingObserver {
  final barcodeCtrl = TextEditingController();
  final searchCtrl = TextEditingController();
  String search = '';
  String? lastCode;
  DateTime? lastAt;
  String? info;
  bool finishing = false;

  /// Produk yang barusan ditambahkan — baris disorot + tag BARU.
  int? _lastScannedId;

  /// Jumlah layer di atas kamera (popup/detail). >0 = kamera wajib mati.
  int _navDepth = 0;

  /// true bila user sudah mengetuk placeholder (kamera boleh nyala).
  bool _cameraOn = false;
  bool _starting = false;

  /// Guard anti-tumpuk: cegah _resolveBarcode paralel (scan cepat /
  /// tap ganda) membuka dialog/halaman bertumpuk.
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    barcodeCtrl.dispose();
    searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App di-minimize/layar mati = kamera mati total (anti panas).
    if (!mounted) return;
    final controller = ref.read(mobileScannerControllerProvider);
    if (state == AppLifecycleState.resumed) {
      if (_cameraOn && _navDepth == 0) controller.start();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      controller.stop();
    }
  }

  /// Buka popup/layar lain dengan kamera dimatikan, nyalakan lagi saat kembali
  /// (hanya bila user memang sudah membuka kamera).
  Future<T?> _withCameraOff<T>(Future<T?> Function() open) async {
    final controller = ref.read(mobileScannerControllerProvider);
    _navDepth++;
    await controller.stop();
    try {
      return await open();
    } finally {
      _navDepth--;
      if (mounted && _cameraOn && _navDepth == 0) {
        await controller.start();
      }
    }
  }

  /// Nyalakan kamera dari placeholder. Permission ditolak = snackbar,
  /// ketuk lagi = request ulang.
  Future<void> _openCamera() async {
    if (_cameraOn || _starting) return;
    setState(() => _starting = true);
    try {
      await ref.read(mobileScannerControllerProvider).start();
      if (mounted) setState(() => _cameraOn = true);
    } on MobileScannerException catch (e) {
      if (!mounted) return;
      final denied = e.errorCode == MobileScannerErrorCode.permissionDenied;
      showRitaToast(
        context,
        denied
            ? 'Izin kamera ditolak. Ketuk area kamera lagi untuk mengizinkan.'
            : 'Kamera gagal dibuka: ${e.errorCode.name}',
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  /// Matikan kamera manual (toggle) — kembali ke placeholder, hemat berat.
  Future<void> _closeCamera() async {
    if (!_cameraOn) return;
    try {
      await ref.read(mobileScannerControllerProvider).stop();
    } finally {
      if (mounted) setState(() => _cameraOn = false);
    }
  }

  void _onDetect(String code) {
    // Anti-tumpuk: abaikan tembakan kamera selagi dialog/halaman terbuka
    // atau resolve sebelumnya belum selesai.
    if (_resolving || _navDepth > 0) return;
    final now = DateTime.now();
    // Kamera menembak berulang — abaikan kode sama dalam 2 detik.
    if (code == lastCode &&
        lastAt != null &&
        now.difference(lastAt!).inSeconds < 2) {
      return;
    }
    lastCode = code;
    lastAt = now;
    barcodeCtrl.text = code;
    _resolveBarcode(code);
  }

  /// Aturan: barcode baru → langsung ke detail; tidak dikenal / sudah ada
  /// → pesan saja, tetap di daftar.
  Future<void> _resolveBarcode(String raw) async {
    // Anti-tumpuk: satu resolve dalam satu waktu.
    if (_resolving || _navDepth > 0) return;
    final barcode = raw.trim();
    if (barcode.isEmpty) return;
    _resolving = true;
    try {
      await _resolveBarcodeInner(barcode);
    } finally {
      _resolving = false;
    }
  }

  Future<void> _resolveBarcodeInner(String barcode) async {
    setState(() => info = null);
    final product = await ref
        .read(productRepositoryProvider)
        .findByBarcode(barcode);
    if (!mounted) return;
    if (product == null) {
      setState(() => info = AppMessages.productNotFound);
      return;
    }
    final productId = (product['product_id'] as num).toInt();
    final existing = await ref
        .read(soRepositoryProvider)
        .findByRakAndProduct(widget.rakId, productId);
    if (!mounted) return;
    if (existing != null) {
      await _duplicateDialog(
        product,
        (existing['quantity'] as num).toInt(),
        barcode,
      );
      return;
    }
    barcodeCtrl.clear();
    setState(() => _lastScannedId = productId);
    await _withCameraOff(
      () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(
            rakId: widget.rakId,
            rakName: widget.rakName,
            productId: productId,
            scannedProduct: product,
            scannedBarcode: barcode,
          ),
        ),
      ),
    );
    ref.invalidate(rakItemsProvider(widget.rakId));
  }

  /// Popup saat barcode sudah pernah di-scan di rak ini.
  /// Detail produk tampil di dalam popup + input jumlah.
  /// Tambah = tercatat + input, Ganti = input jadi qty akhir.
  Future<void> _duplicateDialog(
    Map<String, dynamic> product,
    int recordedQty,
    String scannedBarcode,
  ) async {
    final productId = (product['product_id'] as num).toInt();
    final qtyCtrl = TextEditingController(text: '1');
    String? err;
    try {
      final action = await _withCameraOff(
        () => showRitaDialog<String>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setD) => RitaAlert(
              title: const RitaDialogTitle(
                icon: Icons.check_circle,
                text: 'Sudah di-scan',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${product['name']}', style: RitaType.cardTitle),
                  const SizedBox(height: 4),
                  Text('Barcode: $scannedBarcode', style: RitaType.meta),
                  const Divider(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 14,
                    ),
                    decoration: BoxDecoration(
                      color: RitaPalette.primarySurface,
                      borderRadius: BorderRadius.circular(RitaRadius.sm),
                    ),
                    child: Text(
                      'Tercatat: $recordedQty pcs',
                      style: RitaType.data.copyWith(fontSize: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Jumlah',
                      hintText: 'contoh: 1',
                      errorText: err,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RitaRadius.md),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Batal',
                    style: TextStyle(
                      color: RitaPalette.grey,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: RitaPalette.primary,
                    side: const BorderSide(color: RitaPalette.primary),
                  ),
                  onPressed: () {
                    if (!_validQty(qtyCtrl.text)) {
                      setD(() => err = 'Jumlah harus lebih dari 0.');
                      return;
                    }
                    Navigator.pop(ctx, 'replace');
                  },
                  child: const Text(
                    'Ganti',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    if (!_validQty(qtyCtrl.text)) {
                      setD(() => err = 'Jumlah harus lebih dari 0.');
                      return;
                    }
                    Navigator.pop(ctx, 'add');
                  },
                  child: const Text(
                    'Tambah',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (!mounted || action == null) return;
      final qty = int.parse(qtyCtrl.text.trim());
      final so = ref.read(soRepositoryProvider);
      final finalQty = await so.upsertScan(
        rakId: widget.rakId,
        rakName: widget.rakName,
        productId: productId,
        plu: (product['plu'] as String?) ?? '',
        barcode: scannedBarcode,
        productName: product['name'] as String,
        quantity: qty,
        mode: action,
      );
      ref.invalidate(rakItemsProvider(widget.rakId));
      ref.invalidate(pendingCountProvider);
      barcodeCtrl.clear();
      if (mounted) {
        setState(() => _lastScannedId = productId);
        showRitaToast(
          context,
          action == 'add'
              ? 'Ditambah - ${product['name']} x $finalQty'
              : 'Diubah - ${product['name']} x $finalQty',
          success: true,
        );
      }
    } finally {
      qtyCtrl.dispose();
    }
  }

  bool _validQty(String v) => (int.tryParse(v.trim()) ?? 0) > 0;

  /// SELESAI rak: wajib online + upload sukses, baru tandai done.
  /// Offline/gagal = tetap di layar scan, tidak ditandai selesai.
  Future<void> _finish() async {
    if (!ref.read(isOnlineProvider)) {
      if (mounted) {
        await showRitaError(
          context: context,
          title: 'Wajib online',
          message:
              'Wajib online untuk submit rak ${widget.rakName}. Data tetap aman di perangkat.',
        );
      }
      return;
    }
    setState(() => finishing = true);
    try {
      try {
        await ref.read(uploadServiceProvider).uploadRak(widget.rakId);
      } catch (e) {
        if (mounted) {
          final msg = e is AppFailure ? e.userMessage : e.toString();
          await showRitaError(
            context: context,
            title: 'Upload gagal',
            message: 'Rak ${widget.rakName} gagal terupload. $msg',
          );
        }
        return;
      }
      await ref.read(sessionRepositoryProvider).markRakDone(widget.rakId);
      ref.invalidate(pendingCountProvider);
      final session = ref.read(activeSessionProvider);
      if (session != null) {
        ref.invalidate(rackListProvider(session.inspectorId));
      }
      if (mounted) {
        showRitaToast(
          context,
          'Rak ${widget.rakName} selesai & terupload',
          success: true,
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(mobileScannerControllerProvider);
    final items = ref.watch(rakItemsProvider(widget.rakId));
    final session = ref.watch(activeSessionProvider);

    final filtered = items.maybeWhen(
      data: (rows) => search.isEmpty
          ? rows
          : rows
                .where(
                  (r) =>
                      (r['product_name'] as String).toLowerCase().contains(
                        search.toLowerCase(),
                      ) ||
                      (r['barcode'] as String).contains(search) ||
                      ((r['plu'] as String?) ?? '').contains(search),
                )
                .toList(),
      orElse: () => const <Map<String, dynamic>>[],
    );

    final totalQty = items.maybeWhen(
      data: (rows) =>
          rows.fold<int>(0, (sum, r) => sum + (r['quantity'] as num).toInt()),
      orElse: () => 0,
    );

    return Scaffold(
      appBar: RitaBand(
        title: 'Rak ${widget.rakName}',
        subtitle: session == null
            ? '$totalQty item'
            : '${session.sesiCode} - $totalQty item',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              RitaSpace.screen,
              RitaSpace.sm,
              RitaSpace.screen,
              0,
            ),
            child: _CameraArea(
              controller: controller,
              cameraOn: _cameraOn,
              starting: _starting,
              onOpen: _openCamera,
              onToggle: _closeCamera,
              onCode: _onDetect,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              RitaSpace.screen,
              RitaSpace.md,
              RitaSpace.screen,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PLU / BARCODE MANUAL', style: RitaType.fieldLabel),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: RitaSizes.field,
                        child: TextField(
                          controller: barcodeCtrl,
                          keyboardType: TextInputType.number,
                          onSubmitted: _resolveBarcode,
                          style: RitaType.body,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: RitaSpace.md,
                            ),
                            hintText: 'Mis. 8991234567890',
                            hintStyle: RitaType.hint,
                            filled: true,
                            fillColor: RitaPalette.white,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                RitaRadius.md,
                              ),
                              borderSide: const BorderSide(
                                color: RitaPalette.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                RitaRadius.md,
                              ),
                              borderSide: const BorderSide(
                                color: RitaPalette.focus,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: RitaSpace.xs),
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: FilledButton(
                        onPressed: () => _resolveBarcode(barcodeCtrl.text),
                        style: FilledButton.styleFrom(
                          backgroundColor: RitaPalette.primary,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(RitaRadius.md),
                          ),
                        ),
                        child: const Icon(
                          Icons.search,
                          size: RitaSizes.iconGlyph,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: RitaSpace.sm),
                RitaSearchField(
                  controller: searchCtrl,
                  hint: 'Cari item di rak ini...',
                  onChanged: (v) => setState(() => search = v.trim()),
                ),
                if (info != null) ...[
                  const SizedBox(height: RitaSpace.sm),
                  RitaBanner(kind: RitaBannerKind.error, title: info!),
                ],
              ],
            ),
          ),
          const SizedBox(height: RitaSpace.sm),
          Expanded(
            child: items.when(
              data: (_) {
                if (filtered.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(RitaSpace.screen),
                    children: const [
                      RitaEmptyState(
                        icon: Icons.qr_code_scanner,
                        title: 'Rak masih kosong',
                        message: 'Scan barcode produk pertama di rak ini.',
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    RitaSpace.screen,
                    0,
                    RitaSpace.screen,
                    RitaSpace.screen,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: RitaSpace.sm),
                  itemBuilder: (_, i) {
                    final r = filtered[i];
                    final productId = (r['product_id'] as num).toInt();
                    return _ItemCard(
                      row: r,
                      isNew: productId == _lastScannedId,
                      onTap: () {
                        // Anti-tumpuk: abaikan tap ganda selagi halaman
                        // detail / dialog masih terbuka.
                        if (_resolving || _navDepth > 0) return;
                        _withCameraOff(
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(
                                rakId: widget.rakId,
                                rakName: widget.rakName,
                                productId: productId,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(RitaSpace.screen),
                child: RitaListSkeleton(height: 76),
              ),
              error: (e, _) =>
                  Center(child: Text('Gagal memuat: $e', style: RitaType.meta)),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(RitaSpace.screen),
          child: RitaPrimaryButton(
            label: 'SELESAI RAK INI',
            loading: finishing,
            onPressed: finishing ? null : _finish,
          ),
        ),
      ),
    );
  }
}

/// Kartu item hasil scan v5; `isNew` = barusan ditambahkan (tint + BARU).
class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.row, required this.onTap, this.isNew = false});

  final Map<String, dynamic> row;
  final VoidCallback onTap;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return RitaCard(
      onTap: onTap,
      color: isNew ? RitaPalette.primarySurface : RitaPalette.white,
      borderColor: isNew ? RitaPalette.primarySurface : RitaPalette.line,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${row['product_name']}', style: RitaType.cardTitle),
                const SizedBox(height: 4),
                Text('${row['barcode']}', style: RitaType.captionHint),
                if (isNew) ...[
                  const SizedBox(height: RitaSpace.xs),
                  RitaPill.tag(
                    'BARU',
                    bg: RitaPalette.white,
                    fg: RitaPalette.primary,
                    border: null,
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${row['quantity']}', style: RitaType.data),
              Text(
                'PCS',
                style: RitaType.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: RitaPalette.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Area kamera v5: viewfinder 190px (corner marks) + kontrol scrim.
/// MobileScanner SELALU dibangun agar controller attach (start() gagal bila
/// widget belum ada), placeholder menutupinya sampai user mengetuk.
class _CameraArea extends StatelessWidget {
  const _CameraArea({
    required this.controller,
    required this.cameraOn,
    required this.starting,
    required this.onOpen,
    required this.onToggle,
    required this.onCode,
  });
  final MobileScannerController controller;
  final bool cameraOn;
  final bool starting;
  final VoidCallback onOpen;
  final VoidCallback onToggle;
  final void Function(String code) onCode;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(RitaRadius.lg),
      child: SizedBox(
        height: 190,
        width: double.infinity,
        child: Stack(
          children: [
            MobileScanner(
              controller: controller,
              fit: BoxFit.cover,
              onDetect: (capture) {
                final code = capture.barcodes.firstOrNull?.rawValue;
                if (code != null && code.isNotEmpty) onCode(code);
              },
            ),
            // Corner marks viewfinder.
            const Positioned.fill(child: RitaCornerMarks()),
            if (cameraOn) ...[
              Positioned(
                left: RitaSpace.xs,
                top: RitaSpace.xs,
                child: RitaIconButton(
                  icon: Icons.flash_on,
                  color: Colors.white,
                  scrim: true,
                  tooltip: 'Senter',
                  onPressed: () => controller.toggleTorch(),
                ),
              ),
              Positioned(
                right: RitaSpace.xs,
                top: RitaSpace.xs,
                child: RitaIconButton(
                  icon: Icons.cameraswitch,
                  color: Colors.white,
                  scrim: true,
                  tooltip: 'Ganti kamera',
                  onPressed: () => controller.switchCamera(),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: RitaSpace.xs,
                child: Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.55),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: RitaSpace.sm,
                      ),
                    ),
                    onPressed: onToggle,
                    icon: const Icon(Icons.videocam_off, size: 20),
                    label: const Text(
                      'Matikan kamera',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ),
            ] else
              Positioned.fill(
                child: InkWell(
                  onTap: starting ? null : onOpen,
                  child: Container(
                    color: Colors.black,
                    child: Center(
                      child: starting
                          ? const CircularProgressIndicator(
                              color: RitaPalette.primary,
                            )
                          : const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.photo_camera_outlined,
                                  size: 40,
                                  color: RitaPalette.hint,
                                ),
                                SizedBox(height: RitaSpace.xs),
                                Text(
                                  'Ketuk untuk buka kamera',
                                  style: TextStyle(
                                    color: RitaPalette.hint,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 30,
              child: Center(
                child: Text(
                  'Arahkan ke barcode produk',
                  style: RitaType.captionHint.copyWith(
                    color: cameraOn ? Colors.white70 : RitaPalette.hint,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

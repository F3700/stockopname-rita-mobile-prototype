import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/connectivity/connectivity_providers.dart';
import '../../core/database/product_repository.dart';
import '../../core/database/session_repository.dart';
import '../../core/database/so_repository.dart';
import '../../core/error/app_error.dart';
import '../../core/scanner/barcode_scanner_service.dart';
import '../../core/ui/rita_dialog.dart';
import '../../core/ui/rita_theme.dart';
import '../racks/rack_providers.dart';
import '../setup/setup_service.dart';
import '../upload/upload_service.dart';
import 'product_detail_screen.dart';

/// Item hasil scan satu rak. Invalidate tiap ada simpan/ubah.
final rakItemsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, rakId) {
  return ref.watch(soRepositoryProvider).listByRak(rakId);
});

/// Scan per rak: kamera + PLU manual + daftar hasil + SELESAI.
class RackScanScreen extends ConsumerStatefulWidget {
  const RackScanScreen(
      {super.key, required this.rakId, required this.rakName});
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
      final denied =
          e.errorCode == MobileScannerErrorCode.permissionDenied;
      hideStackedSnackBar(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(denied
              ? 'Izin kamera ditolak. Ketuk area kamera lagi untuk mengizinkan.'
              : 'Kamera gagal dibuka: ${e.errorCode.name}')));
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
    final product =
        await ref.read(productRepositoryProvider).findByBarcode(barcode);
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
          product, (existing['quantity'] as num).toInt());
      return;
    }
    barcodeCtrl.clear();
    await _withCameraOff(() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
              rakId: widget.rakId,
              rakName: widget.rakName,
              productId: productId,
              scannedProduct: product,
            ))));
  }

  /// Popup saat barcode sudah pernah di-scan di rak ini.
  /// Detail produk tampil di dalam popup + input jumlah.
  /// Tambah = tercatat + input, Ganti = input jadi qty akhir.
  Future<void> _duplicateDialog(
      Map<String, dynamic> product, int recordedQty) async {
    final productId = (product['product_id'] as num).toInt();
    final qtyCtrl = TextEditingController(text: '1');
    String? err;
    try {
      final action = await _withCameraOff(() => showRitaDialog<String>(
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
                Text('${product['name']}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Barcode: ${product['barcode']}',
                    style: const TextStyle(
                        color: RitaColors.grey, fontSize: 14)),
                const Divider(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 14),
                  decoration: BoxDecoration(
                    color: RitaColors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Tercatat: $recordedQty pcs',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: RitaColors.red)),
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
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal',
                    style: TextStyle(
                        color: RitaColors.grey,
                        fontWeight: FontWeight.bold)),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: RitaColors.red,
                  side: const BorderSide(color: RitaColors.red),
                ),
                onPressed: () {
                  if (!_validQty(qtyCtrl.text)) {
                    setD(() => err = 'Jumlah harus lebih dari 0.');
                    return;
                  }
                  Navigator.pop(ctx, 'replace');
                },
                child: const Text('Ganti',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              FilledButton(
                onPressed: () {
                  if (!_validQty(qtyCtrl.text)) {
                    setD(() => err = 'Jumlah harus lebih dari 0.');
                    return;
                  }
                  Navigator.pop(ctx, 'add');
                },
                child: const Text('Tambah',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ));
      if (!mounted || action == null) return;
      final qty = int.parse(qtyCtrl.text.trim());
      final so = ref.read(soRepositoryProvider);
      final finalQty = await so.upsertScan(
        rakId: widget.rakId,
        rakName: widget.rakName,
        productId: productId,
        barcode: product['barcode'] as String,
        productName: product['name'] as String,
        quantity: qty,
        mode: action,
      );
      ref.invalidate(rakItemsProvider(widget.rakId));
      ref.invalidate(pendingCountProvider);
      barcodeCtrl.clear();
      if (mounted) {
        hideStackedSnackBar(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(action == 'add'
                ? 'Ditambah ✓ (${product['name']} x $finalQty)'
                : 'Diubah ✓ (${product['name']} x $finalQty)')));
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
        hideStackedSnackBar(context);
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
          hideStackedSnackBar(context);
          await showRitaError(
            context: context,
            title: 'Upload gagal',
            message: 'Rak ${widget.rakName} gagal terupload. $msg',
          );
        }
        return;
      }
      await ref
          .read(sessionRepositoryProvider)
          .markRakDone(widget.rakId);
      ref.invalidate(pendingCountProvider);
      final session = ref.read(activeSessionProvider);
      if (session != null) {
        ref.invalidate(rackListProvider(session.inspectorId));
      }
      if (mounted) {
        hideStackedSnackBar(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Rak ${widget.rakName} selesai & terupload ✓')));
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

    final filtered = items.maybeWhen(
      data: (rows) => search.isEmpty
          ? rows
          : rows
              .where((r) =>
                  (r['product_name'] as String)
                      .toLowerCase()
                      .contains(search.toLowerCase()) ||
                  (r['barcode'] as String).contains(search))
              .toList(),
      orElse: () => const <Map<String, dynamic>>[],
    );

    return Scaffold(
      appBar: AppBar(title: Text(widget.rakName)),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(
                left: 16, right: 16, bottom: 6, top: 16),
            width: double.infinity,
            height: 210,
            child: _CameraArea(
              controller: controller,
              cameraOn: _cameraOn,
              starting: _starting,
              onOpen: _openCamera,
              onToggle: _closeCamera,
              onCode: _onDetect,
            ),
          ),
          const Text('Scan Barcode',
              style:
                  TextStyle(color: RitaColors.lightGrey, fontSize: 12)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('MASUKAN PLU/BARCODE MANUAL',
                    style: TextStyle(
                        color: RitaColors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: barcodeCtrl,
                        keyboardType: TextInputType.number,
                        onSubmitted: _resolveBarcode,
                        decoration: const InputDecoration(
                          hint: Text('contoh: 1234/123123131',
                              style: TextStyle(
                                  color: RitaColors.lightGrey)),
                          focusedBorder: UnderlineInputBorder(
                            borderSide:
                                BorderSide(color: RitaColors.red),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          _resolveBarcode(barcodeCtrl.text),
                      icon: const Icon(Icons.search,
                          color: RitaColors.red, size: 32),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: searchCtrl,
                  onChanged: (v) =>
                      setState(() => search = v.trim()),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(
                            color: RitaColors.red, width: 2)),
                    label: const Text('Search...'),
                    prefixIcon: const Icon(Icons.search,
                        color: Colors.grey),
                  ),
                ),
                if (info != null) ...[
                  const SizedBox(height: 6),
                  Text(info!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: items.when(
              data: (_) {
                if (filtered.isEmpty) {
                  return const Center(
                      child: Text('Belum ada barang di rak ini.',
                          style:
                              TextStyle(color: RitaColors.grey)));
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final r = filtered[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 5),
                      shape: RoundedRectangleBorder(
                        side:
                            const BorderSide(color: Colors.black),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          // Anti-tumpuk: abaikan tap ganda selagi halaman
                          // detail / dialog masih terbuka.
                          if (_resolving || _navDepth > 0) return;
                          _withCameraOff(() =>
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => ProductDetailScreen(
                                        rakId: widget.rakId,
                                        rakName: widget.rakName,
                                        productId:
                                            (r['product_id'] as num)
                                                .toInt(),
                                      ))));
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 20),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('${r['product_name']}',
                                        style: const TextStyle(
                                            color: RitaColors.red,
                                            fontSize: 16,
                                            fontWeight:
                                                FontWeight.bold)),
                                    Text('Barcode: ${r['barcode']}',
                                        style: const TextStyle(
                                            color: RitaColors.grey,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  Text('${r['quantity']}',
                                      style: const TextStyle(
                                          color: RitaColors.red,
                                          fontSize: 20,
                                          fontWeight:
                                              FontWeight.bold)),
                                  const Text('QTY',
                                      style: TextStyle(
                                          color: RitaColors.grey,
                                          fontSize: 14,
                                          fontWeight:
                                              FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat: $e')),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FilledButton(
            onPressed: finishing ? null : _finish,
            child: Text(finishing ? 'Menyimpan...' : 'SELESAI'),
          ),
        ),
      ),
    );
  }
}

/// Area kamera: MobileScanner SELALU dibangun agar controller attach
/// (start() gagal bila widget belum ada), placeholder menutupinya sampai
/// user mengetuk.
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
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          MobileScanner(
            controller: controller,
            fit: BoxFit.cover,
            onDetect: (capture) {
              final code =
                  capture.barcodes.firstOrNull?.rawValue;
              if (code != null && code.isNotEmpty) onCode(code);
            },
          ),
          if (cameraOn) ...[
            Positioned(
              left: 5,
              top: 5,
              child: IconButton(
                onPressed: () => controller.switchCamera(),
                icon: const Icon(Icons.cameraswitch_rounded,
                    size: 30, color: RitaColors.red),
              ),
            ),
            Positioned(
              right: 5,
              top: 5,
              child: IconButton(
                onPressed: () => controller.toggleTorch(),
                icon: const Icon(Icons.flash_on,
                    size: 30, color: RitaColors.red),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 6,
              child: Center(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onToggle,
                  icon: const Icon(Icons.videocam_off, size: 20),
                  label: const Text('Matikan kamera'),
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
                            color: RitaColors.red)
                        : const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.photo_camera_outlined,
                                  size: 48, color: RitaColors.grey),
                              SizedBox(height: 8),
                              Text('Ketuk untuk buka kamera',
                                  style: TextStyle(
                                      color: RitaColors.grey,
                                      fontSize: 14)),
                            ],
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

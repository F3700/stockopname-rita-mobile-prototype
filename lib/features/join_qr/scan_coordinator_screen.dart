import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/error/app_error.dart';
import '../../core/logging/app_logger.dart';
import '../../core/network/qr_join_api.dart';
import '../../core/qr/coor_qr.dart';
import '../../core/ui/rita_dialog.dart';
import '../../core/ui/rita_theme.dart';
import '../catalog/sync_gate.dart';
import 'join_qr_form_screen.dart';
import 'join_qr_service.dart';

/// Scan QR koordinator (`RITA-COOR-<id>`) + fallback tempel manual.
/// Sukses scan + validasi → langsung ke [JoinQrFormScreen] yang menampilkan
/// info coor/sesi di atas form. Non-IN_PROGRESS tertahan di sini dengan pesan.
/// Flow manual tidak tersentuh.
///
/// F1: controller kamera MILIK layar ini (dibuat di initState, dispose di
/// dispose) — tidak share provider dengan layar scan rak, agar tidak ada
/// state basi antar-layar yang bikin freeze/hang.
class ScanCoordinatorScreen extends ConsumerStatefulWidget {
  const ScanCoordinatorScreen({super.key});

  @override
  ConsumerState<ScanCoordinatorScreen> createState() =>
      _ScanCoordinatorScreenState();
}

class _ScanCoordinatorScreenState extends ConsumerState<ScanCoordinatorScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController cameraController;
  CancelToken? previewToken;
  String? error;
  bool lastRetryable = false;
  String? lastCode;
  DateTime? lastAt;
  bool busyPreview = false;
  bool cameraOn = false;
  bool starting = false;
  bool resolving = false;
  int navDepth = 0;

  static const _startTimeout = Duration(seconds: 10);
  static const _previewTimeout = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 1000,
      autoStart: false,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    previewToken?.cancel('Layar scan ditutup.');
    previewToken = null;
    cameraController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // F4: jangan biarkan start/stop tanpa catch — dulu unawaited mentah
    // berpotensi unhandled async error (crash) saat resume.
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      if (cameraOn && navDepth == 0) {
        cameraController.start().then((_) {}).catchError((Object e) {
          appLogger.w('QR camera resume-start gagal: $e');
        });
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      cameraController.stop().then((_) {}).catchError((Object e) {
        appLogger.w('QR camera lifecycle-stop gagal: $e');
      });
    }
  }

  /// F2: start dibatasi timeout — bila native tidak kembali (stall izin /
  /// kamera), tampilkan pesan, bukan spinner abadi + tap mati.
  Future<void> _openCamera() async {
    if (cameraOn || starting) return;
    setState(() => starting = true);
    try {
      await cameraController.start().timeout(_startTimeout);
      if (mounted) setState(() => cameraOn = true);
    } on TimeoutException {
      appLogger.w('QR camera start timeout > ${_startTimeout.inSeconds}s.');
      if (!mounted) return;
      try {
        await cameraController.stop();
      } catch (_) {
        // Abaikan — hanya reset state lokal.
      }
      if (!mounted) return;
      hideStackedSnackBar(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Kamera tidak merespons. Ketuk area kamera untuk coba lagi.')));
    } on MobileScannerException catch (e) {
      if (!mounted) return;
      final denied = e.errorCode == MobileScannerErrorCode.permissionDenied;
      hideStackedSnackBar(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(denied
              ? 'Izin kamera ditolak. Ketuk area kamera lagi untuk mengizinkan.'
              : 'Kamera gagal dibuka: ${e.errorCode.name}')));
    } finally {
      if (mounted) setState(() => starting = false);
    }
  }

  Future<void> _closeCamera() async {
    if (!cameraOn) return;
    try {
      await cameraController.stop();
    } catch (e) {
      appLogger.w('QR camera stop gagal: $e');
    } finally {
      if (mounted) setState(() => cameraOn = false);
    }
  }

  void _onDetect(String code) {
    if (resolving || navDepth > 0) return;
    final now = DateTime.now();
    if (code == lastCode &&
        lastAt != null &&
        now.difference(lastAt!).inSeconds < 2) {
      return;
    }
    lastCode = code;
    lastAt = now;
    _validateAndPreview(code);
  }

  /// Validasi client + preview via GET by id (Dio pinned hosted).
  Future<void> _validateAndPreview(String raw) async {
    if (resolving) return;
    final container = ProviderScope.containerOf(context);
    final coorId = CoorQr.tryParseCoorQr(raw);
    if (coorId == null) {
      setState(() {
        error = 'QR tidak valid. Contoh format: RITA-COOR-12.';
        lastRetryable = false;
      });
      return;
    }
    final online = await requireOnline(context, container, 'Preview QR');
    if (!online || !mounted) return;
    setState(() {
      busyPreview = true;
      error = null;
    });
    resolving = true;
    // F3: matikan kamera SEBELUM request jaringan — deteksi ~1/detik
    // tidak boleh memicu preview berulang + dialog bertumpuk.
    try {
      await cameraController.stop();
    } catch (e) {
      appLogger.w('QR camera stop pra-preview gagal: $e');
    }
    if (mounted) setState(() => cameraOn = false);
    // F4: request bisa dibatalkan saat layar ditutup.
    previewToken?.cancel('Preview baru dimulai.');
    final token = previewToken = CancelToken();
    try {
      final data = await ref
          .read(joinQrServiceProvider)
          .preview(coorId, cancelToken: token)
          .timeout(_previewTimeout, onTimeout: () {
        token.cancel('Preview timeout.');
        throw TimeoutException(
            'Preview timeout > ${_previewTimeout.inSeconds}s.');
      });
      if (!mounted) return;
      // Sukses validasi → langsung ke form input inspector + rak (info
      // coor/sesi tampil di atas form). Tertahan di sini bila non-aktif.
      if (!data.isJoinable) {
        final st = data.status.trim().isEmpty ? '-' : data.status.trim();
        setState(() {
          error = 'Koordinator ${data.code} sedang $st. '
              'Hanya koordinator IN_PROGRESS yang bisa di-join.';
          lastRetryable = false;
        });
        return;
      }
      final qr = CoorQr.format(coorId);
      navDepth++;
      try {
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => JoinQrFormScreen(
                  coordinatorQr: qr,
                  preview: data,
                )));
      } finally {
        navDepth--;
      }
      return;
    } on DioException catch (e) {
      // F4: layar ditutup saat request jalan = abaikan diam-diam.
      // Cancel diteruskan mentah oleh QrJoinApi (bukan QrJoinFailure).
      if (e.type == DioExceptionType.cancel) return;
      if (!mounted) return;
      final data = e.response?.data;
      final server = data is Map<String, dynamic> &&
              data['message'] is String &&
              (data['message'] as String).isNotEmpty
          ? data['message'] as String
          : '';
      final msg = server.isEmpty
          ? 'Gagal memuat preview (${e.type.name}). Coba lagi.'
          : server;
      setState(() {
        error = msg;
        lastRetryable = true;
      });
      if (mounted) {
        await showRitaError(
          context: context,
          title: 'Preview gagal',
          message: msg,
        );
      }
    } on TimeoutException {
      if (!mounted) return;
      const msg =
          'Server tidak merespons dalam 20 detik. Periksa koneksi lalu coba lagi.';
      setState(() {
        error = msg;
        lastRetryable = true;
      });
      if (mounted) {
        await showRitaError(
          context: context,
          title: 'Preview gagal',
          message: msg,
        );
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e is AppFailure ? e.userMessage : e.toString();
      final retryable = e is QrJoinFailure && e.retryable;
      setState(() {
        error = msg;
        lastRetryable = retryable;
      });
      if (retryable && mounted) {
        await showRitaError(
          context: context,
          title: 'Preview gagal',
          message: msg,
        );
      }
    } finally {
      resolving = false;
      if (mounted) setState(() => busyPreview = false);
    }
  }

  /// Retry memakai hasil pindaian terakhir — tidak ada input manual lagi.
  Future<void> _retryPreview() async {
    final qr = lastCode;
    if (qr == null) return;
    await _validateAndPreview(qr);
  }

  @override
  Widget build(BuildContext context) {
    final lastError = error;
    final isRetryable =
        lastError != null && !busyPreview && lastRetryable;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          children: [
            Text('Scan QR Coordinator',
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            Text('Arahkan kamera ke QR admin',
                style: TextStyle(color: RitaColors.grey, fontSize: 12)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: 260,
              child: _CameraArea(
                controller: cameraController,
                cameraOn: cameraOn,
                starting: starting,
                onOpen: _openCamera,
                onToggle: _closeCamera,
                onCode: _onDetect,
              ),
            ),
            if (busyPreview) ...[
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator()),
            ],
            if (lastError != null) ...[
              const SizedBox(height: 12),
              Text(lastError, style: const TextStyle(color: Colors.red)),
              if (!cameraOn) ...[
                const SizedBox(height: 4),
                const Text('Ketuk area kamera untuk pindai ulang.',
                    style:
                        TextStyle(color: RitaColors.grey, fontSize: 12)),
              ],
              if (isRetryable) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: busyPreview ? null : _retryPreview,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba lagi'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Area kamera: MobileScanner SELALU dibangun agar controller attach
/// (start() gagal bila widget belum ada), placeholder menutupinya sampai
/// user mengetuk. F2: error native ditampilkan sebagai pesan + cara coba
/// lagi, bukan layar hitam yang dikira hang.
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
            errorBuilder: (context, error) => Container(
              color: Colors.black,
              padding: const EdgeInsets.all(17),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 40, color: RitaColors.grey),
                    const SizedBox(height: 8),
                    Text(
                      'Kamera bermasalah: ${error.errorCode.name}\nKetuk area ini untuk coba lagi.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: RitaColors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            onDetect: (capture) {
              final code = capture.barcodes.firstOrNull?.rawValue;
              if (code != null && code.isNotEmpty) onCode(code);
            },
          ),
          if (cameraOn)
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
            )
          else
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
                              Icon(Icons.qr_code_scanner,
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

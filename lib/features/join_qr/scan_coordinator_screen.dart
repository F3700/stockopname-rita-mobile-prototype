import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/error/app_error.dart';
import '../../core/logging/app_logger.dart';
import '../../core/network/qr_join_api.dart';
import '../../core/qr/coor_qr.dart';
import '../../core/ui/design_system/rita_band.dart';
import '../../core/ui/design_system/rita_feedback.dart';
import '../../core/ui/design_system/rita_states.dart';
import '../../core/ui/design_system/rita_tokens.dart';
import '../../core/ui/design_system/rita_viewfinder.dart';
import '../../core/ui/rita_dialog.dart';
import '../catalog/sync_gate.dart';
import 'join_qr_form_screen.dart';
import 'join_qr_service.dart';

/// Scan QR koordinator (v5): viewfinder + validasi preview.
/// Sukses scan + validasi → langsung ke [JoinQrFormScreen]. Non-IN_PROGRESS
/// tertahan di sini dengan pesan. Flow manual tidak tersentuh.
///
/// Controller kamera MILIK layar ini (dibuat di initState, dispose di
/// dispose) — tidak share provider dengan layar scan rak.
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
    // Jangan biarkan start/stop tanpa catch — hindari unhandled async error.
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

  /// Start dibatasi timeout — bila native tidak kembali (stall izin /
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
      showRitaToast(
        context,
        'Kamera tidak merespons. Ketuk area kamera untuk coba lagi.',
      );
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
    // Matikan kamera SEBELUM request jaringan — deteksi ~1/detik
    // tidak boleh memicu preview berulang + dialog bertumpuk.
    try {
      await cameraController.stop();
    } catch (e) {
      appLogger.w('QR camera stop pra-preview gagal: $e');
    }
    if (mounted) setState(() => cameraOn = false);
    // Request bisa dibatalkan saat layar ditutup.
    previewToken?.cancel('Preview baru dimulai.');
    final token = previewToken = CancelToken();
    try {
      final data = await ref
          .read(joinQrServiceProvider)
          .preview(coorId, cancelToken: token)
          .timeout(
            _previewTimeout,
            onTimeout: () {
              token.cancel('Preview timeout.');
              throw TimeoutException(
                'Preview timeout > ${_previewTimeout.inSeconds}s.',
              );
            },
          );
      if (!mounted) return;
      // Sukses validasi → langsung ke form input inspector + rak (info
      // coor/sesi tampil di atas form). Tertahan di sini bila non-aktif.
      if (!data.isJoinable) {
        final st = data.status.trim().isEmpty ? '-' : data.status.trim();
        setState(() {
          error =
              'Koordinator ${data.code} sedang $st. '
              'Hanya koordinator IN_PROGRESS yang bisa di-join.';
          lastRetryable = false;
        });
        return;
      }
      final qr = CoorQr.format(coorId);
      navDepth++;
      try {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => JoinQrFormScreen(coordinatorQr: qr, preview: data),
          ),
        );
      } finally {
        navDepth--;
      }
      return;
    } on DioException catch (e) {
      // Layar ditutup saat request jalan = abaikan diam-diam.
      if (e.type == DioExceptionType.cancel) return;
      if (!mounted) return;
      final data = e.response?.data;
      final server =
          data is Map<String, dynamic> &&
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
    final isRetryable = lastError != null && !busyPreview && lastRetryable;
    return Scaffold(
      appBar: RitaBand(
        title: 'Scan QR Coordinator',
        subtitle: 'Tempel ke QR admin',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(RitaSpace.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CameraArea(
              controller: cameraController,
              cameraOn: cameraOn,
              starting: starting,
              onOpen: _openCamera,
              onToggle: _closeCamera,
              onCode: _onDetect,
            ),
            if (busyPreview) ...[
              const SizedBox(height: RitaSpace.md),
              const RitaLoading(label: 'Memvalidasi QR...'),
            ],
            if (lastError != null) ...[
              const SizedBox(height: RitaSpace.md),
              RitaBanner(
                kind: RitaBannerKind.error,
                title: lastError,
                actionLabel: isRetryable ? 'Coba lagi' : null,
                onAction: isRetryable ? _retryPreview : null,
              ),
              if (!cameraOn) ...[
                const SizedBox(height: RitaSpace.xs),
                const Text(
                  'Ketuk area kamera untuk pindai ulang.',
                  style: RitaType.captionHint,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Area kamera QR v5 (300px): viewfinder + kontrol scrim + errorBuilder.
/// MobileScanner SELALU dibangun agar controller attach; placeholder
/// menutupinya sampai user mengetuk.
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
        height: 300,
        width: double.infinity,
        child: Stack(
          children: [
            MobileScanner(
              controller: controller,
              fit: BoxFit.cover,
              errorBuilder: (context, error) => Container(
                color: Colors.black,
                padding: const EdgeInsets.all(RitaSpace.md),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 40,
                        color: RitaPalette.hint,
                      ),
                      const SizedBox(height: RitaSpace.xs),
                      Text(
                        'Kamera bermasalah: ${error.errorCode.name}\nKetuk area ini untuk coba lagi.',
                        textAlign: TextAlign.center,
                        style: RitaType.captionHint,
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
            const Positioned.fill(child: RitaCornerMarks()),
            if (cameraOn)
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
                              color: RitaPalette.primary,
                            )
                          : const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.qr_code_scanner,
                                  size: 48,
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
              bottom: 44,
              child: Center(
                child: Text(
                  'Sejajarkan QR dalam bingkai',
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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Abstraksi agar UI tidak tergantung paket scanner tertentu.
abstract class BarcodeScannerService {
  Future<String?> scanOnce();
}

final barcodeScannerServiceProvider =
    Provider<BarcodeScannerService>((ref) => MobileScannerService());

class MobileScannerService implements BarcodeScannerService {
  @override
  Future<String?> scanOnce() async {
    // Dipakai via widget MobileScanner di ScanScreen (continuous),
    // method ini untuk fallback satu-kali bila dibutuhkan.
    return null;
  }
}

/// Controller kamera bersama agar tidak dibuat ulang tiap rebuild.
/// detectionTimeoutMs menahan laju deteksi ML (hemat CPU/panas) — 1x/detik
/// lebih dari cukup untuk scan gudang. autoStart mati: kamera hanya nyala
/// setelah user mengetuk placeholder (hemat baterai + tidak kaget permission).
final mobileScannerControllerProvider =
    Provider.autoDispose<MobileScannerController>((ref) {
  final controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 1000,
    autoStart: false,
  );
  ref.onDispose(controller.dispose);
  return controller;
});

import '../error/app_error.dart';

/// Parser QR koordinator — mirror dari backend `internal/helper/coor_qr.go`.
/// Format: `RITA-COOR-<id>`, contoh `RITA-COOR-12`.
/// Aturan: trim spasi, prefix case-insensitive, id integer > 0.
/// File baru untuk flow QR — util lama tidak diubah.
class CoorQr {
  const CoorQr._();

  static const String prefix = 'RITA-COOR-';
  static final RegExp _pattern = RegExp(r'^RITA-COOR-(\d+)$');

  /// Bentuk payload QR untuk id koordinator. Dipakai untuk validasi round-trip.
  static String format(int id) => '$prefix$id';

  /// Return id koordinator, atau null bila format salah.
  static int? tryParseCoorQr(String? raw) {
    if (raw == null) return null;
    final upper = raw.trim().toUpperCase();
    if (upper.isEmpty) return null;
    final match = _pattern.firstMatch(upper);
    if (match == null) return null;
    final id = int.tryParse(match.group(1)!);
    if (id == null || id <= 0) return null;
    return id;
  }

  /// Seperti [tryParseCoorQr] tapi throw [AppFailure] ramah gudang.
  static int parseCoorQrOrThrow(String raw) {
    final id = tryParseCoorQr(raw);
    if (id == null) {
      throw const AppFailure(
        'QR tidak valid. Contoh format: RITA-COOR-12.',
      );
    }
    return id;
  }
}

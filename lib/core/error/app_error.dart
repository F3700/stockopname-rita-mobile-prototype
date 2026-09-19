/// Error ramah gudang (Indonesia) + detail teknis untuk log.
class AppFailure implements Exception {
  const AppFailure(this.userMessage, {this.technical});

  final String userMessage;
  final Object? technical;

  @override
  String toString() => 'AppFailure($userMessage)';
}

class AppMessages {
  const AppMessages._();

  static const offlineKept =
      'Tidak ada koneksi internet. Data tetap tersimpan di perangkat.';
  static const productNotFound =
      'Produk tidak ditemukan di master lokal. Lakukan sinkronisasi produk.';
  static const syncFailedKept =
      'Sinkronisasi gagal. Data tetap aman di perangkat, coba lagi nanti.';
  static const invalidQty = 'Jumlah harus lebih dari 0.';
  static const setupIncomplete =
      'Lengkapi kode sesi, koordinator, inspector, dan rak.';
}

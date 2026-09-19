/// API base URL dari --dart-define agar tidak hardcode.
/// Contoh:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
/// Default dev = localhost:8080, prod = https://api.albertt.my.id
class ApiConfig {
  const ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.albertt.my.id',
  );

  static const Duration connectTimeout = Duration(seconds: 15);

  /// Halaman sync 1500 produk butuh napas lebih panjang.
  static const Duration receiveTimeout = Duration(seconds: 60);
}

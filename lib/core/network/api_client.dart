import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/api_config.dart';
import '../error/app_error.dart';
import '../logging/app_logger.dart';
import 'dto.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: ApiConfig.connectTimeout,
    receiveTimeout: ApiConfig.receiveTimeout,
    headers: {'Content-Type': 'application/json'},
  ));
  dio.interceptors.add(LogInterceptor(
    requestBody: false,
    responseBody: false,
    logPrint: (o) => appLogger.d(o),
  ));
  return dio;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider));
});

/// Satu-satunya tempat pemanggilan HTTP. UI dilarang memakai Dio langsung.
class ApiClient {
  ApiClient(this._dio);
  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e, st) {
      appLogger.e('API error: ${e.message}', error: e, stackTrace: st);
      throw AppFailure(_userMessage(e));
    }
  }

  /// Bedakan offline/timeout vs server menolak — jangan samakan semuanya.
  static String _userMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return AppMessages.offlineKept;
      case DioExceptionType.badResponse:
        final data = e.response?.data;
        if (data is Map<String, dynamic> &&
            data['message'] is String &&
            (data['message'] as String).isNotEmpty) {
          return data['message'] as String;
        }
        final code = e.response?.statusCode;
        return 'Server menolak permintaan${code == null ? '' : ' ($code)'}. Coba lagi.';
      case DioExceptionType.cancel:
        return 'Permintaan dibatalkan.';
      case DioExceptionType.badCertificate:
        return 'Sertifikat server tidak valid.';
      // ignore: no_default_cases
      default:
        return AppMessages.offlineKept;
    }
  }

  // ---------- Products ----------

  Future<({List<ProductDto> items, int totalPages})> fetchProducts({
    required int page,
    required int limit,
    String search = '',
  }) =>
      _guard(() async {
        final res = await _dio.get('/products', queryParameters: {
          'page': page,
          'limit': limit,
          if (search.isNotEmpty) 'search': search,
        });
        final data = res.data as Map<String, dynamic>;
        final items = ((data['data'] as List?) ?? [])
            .map((e) => ProductDto.fromJson(e as Map<String, dynamic>))
            .toList();
        final pagination = data['pagination'] as Map<String, dynamic>?;
        final totalPages =
            ((pagination?['total_pages'] ?? pagination?['totalPages']) as num?)
                    ?.toInt() ??
                1;
        return (items: items, totalPages: totalPages);
      });

  Future<({List<ProductDto> items, int totalPages})> syncProducts({
    required int page,
    required int limit,
    required DateTime updatedAfter,
  }) =>
      _guard(() async {
        final res = await _dio.get('/products/sync', queryParameters: {
          'page': page,
          'limit': limit,
          'updated_after': updatedAfter.toIso8601String(),
        });
        final data = res.data as Map<String, dynamic>;
        final items = ((data['data'] as List?) ?? [])
            .map((e) => ProductDto.fromJson(e as Map<String, dynamic>))
            .toList();
        final pagination = data['pagination'] as Map<String, dynamic>?;
        final totalPages =
            ((pagination?['total_pages'] ?? pagination?['totalPages']) as num?)
                    ?.toInt() ??
                1;
        return (items: items, totalPages: totalPages);
      });

  Future<List<DeletedProductDto>> fetchDeletedProducts(
      {DateTime? updatedAfter}) =>
      _guard(() async {
        final res = await _dio.get('/deleted/products', queryParameters: {
          if (updatedAfter != null)
            'updated_after': updatedAfter.toIso8601String(),
        });
        final data = res.data as Map<String, dynamic>;
        return (((data['data'] as List?) ?? [])
            .map((e) => DeletedProductDto.fromJson(e as Map<String, dynamic>))
            .toList());
      });

  // ---------- Setup ----------

  Future<InspectorSetupResult> createInspector({
    required String sesiCode,
    required String coorCode,
    required String inspectorCode,
    required List<String> rak,
  }) =>
      _guard(() async {
        final res = await _dio.post('/stockopname/inspectors', data: {
          'sesi_code': sesiCode,
          'coor_code': coorCode,
          'inspector_code': inspectorCode,
          'rak': rak,
        });
        return InspectorSetupResult.fromJson(
            (res.data as Map<String, dynamic>)['data']
                as Map<String, dynamic>);
      });

  Future<int> createRack(
          {required int inspectorId, required String rakName}) =>
      _guard(() async {
        final res = await _dio.post('/stockopname/racks', data: {
          'inspector_id': inspectorId,
          'rak_name': rakName,
        });
        final data = (res.data as Map<String, dynamic>)['data'];
        if (data is Map<String, dynamic>) {
          return ((data['id']) as num).toInt();
        }
        throw const AppFailure('Respons rack tidak valid.');
      });

  Future<List<RackDto>> fetchRacks({int? inspectorId}) => _guard(() async {
        final res = await _dio.get('/stockopname/racks', queryParameters: {
          if (inspectorId != null) 'inspectorId': inspectorId,
        });
        final data = res.data as Map<String, dynamic>;
        return (((data['data'] as List?) ?? [])
            .map((e) => RackDto.fromJson(e as Map<String, dynamic>))
            .toList());
      });

  // ---------- Upload ----------

  /// Upload batch per rak. 200 = sukses → tandai SYNCED + rak selesai.
  Future<void> uploadByRack(
      {required int rakId, required List<SoUploadItem> items}) =>
      _guard(() async {
        await _dio.post('/stockopname/results/racks', data: {
          'rak_id': rakId,
          'so_products': items.map((e) => e.toJson()).toList(),
        });
      });
}

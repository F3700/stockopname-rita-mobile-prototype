import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/api_config.dart';
import '../error/app_error.dart';
import '../logging/app_logger.dart';
import 'dto.dart';

/// Base URL flow Scan QR — WAJIB hosted, jangan pakai ApiConfig/dart-define.
/// Semua request flow baru (preview + join) lewat Dio ini agar acceptance
/// "ter-hit ke https://api.albertt.my.id" terpenuhi apa pun env dev-nya.
const kQrJoinBaseUrl = 'https://api.albertt.my.id';

final qrDioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: kQrJoinBaseUrl,
    connectTimeout: ApiConfig.connectTimeout,
    receiveTimeout: ApiConfig.receiveTimeout,
    headers: {'Content-Type': 'application/json'},
  ));
  dio.interceptors.add(LogInterceptor(
    request: true,
    requestBody: false,
    responseBody: false,
    logPrint: (o) => appLogger.d(o),
  ));
  return dio;
});

final qrJoinApiClientProvider = Provider<QrJoinApi>((ref) {
  return QrJoinApi(ref.watch(qrDioProvider));
});

/// Error flow QR: bawa statusCode agar UI bisa mapping 400/404/409 vs retry.
/// [retryable] true hanya untuk 500 + gangguan jaringan/timeout.
class QrJoinFailure extends AppFailure {
  const QrJoinFailure(super.userMessage, {this.statusCode, this.retryable = false});

  final int? statusCode;
  final bool retryable;
}

/// Preview koordinator — mirror backend `CoordinatorDetailResponse`
/// (internal/dto/coordinator.go): key camelCase `sessionCode` +
/// `sessionLocation`. Backend lama tidak mengirimnya → jadi ''.
/// Nama koordinator = [code] (DB tidak punya kolom nama).
class CoordinatorPreview {
  const CoordinatorPreview({
    required this.id,
    required this.code,
    required this.sessionCode,
    required this.sessionLocation,
    required this.inspector,
    required this.rackAssigned,
    required this.rackCompleted,
    required this.status,
  });

  final int id;
  final String code;
  final String sessionCode;
  final String sessionLocation;
  final int inspector;
  final int rackAssigned;
  final int rackCompleted;
  final String status;

  /// Lanjut ke form join hanya bila koordinator aktif. Perbandingan
  /// case-insensitive; server tetap validator akhir (409 bila non-aktif).
  bool get isJoinable => status.trim().toUpperCase() == 'IN_PROGRESS';

  factory CoordinatorPreview.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v is num ? v.toInt() : 0;
    return CoordinatorPreview(
      id: asInt(json['id']),
      code: (json['code'] as String?) ?? '',
      sessionCode: (json['sessionCode'] as String?) ??
          (json['session_code'] as String?) ??
          '',
      sessionLocation: (json['sessionLocation'] as String?) ??
          (json['session_location'] as String?) ??
          '',
      inspector: asInt(json['inspector']),
      rackAssigned: asInt(json['rackAssigned']),
      rackCompleted: asInt(json['rackCompleted']),
      status: (json['status'] as String?) ?? '',
    );
  }
}

/// Hasil POST join-by-coordinator-qr: reuse [RackDto] existing.
class QrJoinResult {
  const QrJoinResult({required this.inspectorId, required this.racks});

  final int inspectorId;
  final List<RackDto> racks;
}

/// Satu-satunya client untuk flow QR. Endpoint lama tidak dipakai di sini.
class QrJoinApi {
  QrJoinApi(this._dio);
  final Dio _dio;

  /// GET /stockopname/coordinators/:id untuk preview sebelum join.
  /// [cancelToken] dibatalkan saat layar ditutup agar request tak nyangkut.
  /// Pembatalan diteruskan apa adanya (bukan [QrJoinFailure]) agar UI
  /// bisa mengabaikannya diam-diam.
  Future<CoordinatorPreview> fetchCoordinatorPreview(
    int id, {
    CancelToken? cancelToken,
  }) async {
    appLogger.i('QR preview GET $kQrJoinBaseUrl/stockopname/coordinators/$id');
    try {
      final res = await _dio.get(
        '/stockopname/coordinators/$id',
        cancelToken: cancelToken,
      );
      final data = (res.data as Map<String, dynamic>)['data'];
      if (data is! Map<String, dynamic>) {
        throw const QrJoinFailure('Respons preview koordinator tidak valid.');
      }
      return CoordinatorPreview.fromJson(data);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      throw _mapPreviewError(e);
    }
  }

  /// POST /stockopname/inspectors/join-by-coordinator-qr — endpoint BARU saja.
  Future<QrJoinResult> joinByCoordinatorQr({
    required String coordinatorQr,
    required String inspectorCode,
    required List<String> rak,
    CancelToken? cancelToken,
  }) async {
    appLogger.i(
      'QR join POST $kQrJoinBaseUrl/stockopname/inspectors/join-by-coordinator-qr '
      '(qr=$coordinatorQr inspector=$inspectorCode rak=${rak.length})',
    );
    try {
      final res = await _dio.post(
        '/stockopname/inspectors/join-by-coordinator-qr',
        data: {
          'coordinator_qr': coordinatorQr,
          'inspector_code': inspectorCode,
          'rak': rak,
        },
        cancelToken: cancelToken,
      );
      final data = (res.data as Map<String, dynamic>)['data'];
      if (data is! Map<String, dynamic>) {
        throw const QrJoinFailure('Respons join QR tidak valid.');
      }
      final racks = ((data['rak'] as List?) ?? [])
          .map((e) => RackDto.fromJson(e as Map<String, dynamic>))
          .toList();
      return QrJoinResult(
        inspectorId: (data['inspector_id'] as num).toInt(),
        racks: racks,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      throw _mapJoinError(e);
    }
  }

  static String _serverMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic> &&
        data['message'] is String &&
        (data['message'] as String).isNotEmpty) {
      return data['message'] as String;
    }
    return '';
  }

  static bool _isNetwork(DioException e) {
    if (e.response != null) return false;
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.unknown;
  }

  QrJoinFailure _mapPreviewError(DioException e) {
    if (_isNetwork(e)) {
      return const QrJoinFailure(
        '${AppMessages.offlineKept} Coba lagi.',
        retryable: true,
      );
    }
    final code = e.response?.statusCode;
    final server = _serverMessage(e);
    switch (code) {
      case 400:
        return QrJoinFailure(
          'ID koordinator tidak valid${server.isEmpty ? '.' : ': $server'}',
        );
      case 404:
        return const QrJoinFailure(
          'Koordinator tidak ditemukan. Pastikan QR benar & data sudah masuk ke server.',
        );
      case 500:
        return const QrJoinFailure(
          'Server bermasalah (500). Coba lagi.',
          statusCode: 500,
          retryable: true,
        );
      default:
        if (server.isNotEmpty) return QrJoinFailure(server, statusCode: code);
        return QrJoinFailure(
          'Gagal memuat preview${code == null ? '' : ' ($code)'}. Coba lagi.',
          statusCode: code,
          retryable: true,
        );
    }
  }

  QrJoinFailure _mapJoinError(DioException e) {
    if (_isNetwork(e)) {
      return const QrJoinFailure(
        '${AppMessages.offlineKept} Coba lagi.',
        retryable: true,
      );
    }
    final code = e.response?.statusCode;
    final server = _serverMessage(e);
    switch (code) {
      case 400:
        return QrJoinFailure(
          'Permintaan tidak valid${server.isEmpty ? '. Periksa kode inspector & rak.' : ': $server'}',
          statusCode: 400,
        );
      case 404:
        return QrJoinFailure(
          'Koordinator tidak ditemukan${server.isEmpty ? '. Pastikan QR RITA-COOR-<id> benar.' : ': $server'}',
          statusCode: 404,
        );
      case 409:
        return QrJoinFailure(
          'Konflik${server.isEmpty ? ': inspector/rak sudah terdaftar atau koordinator tidak aktif.' : ': $server'}',
          statusCode: 409,
        );
      case 500:
        return const QrJoinFailure(
          'Server bermasalah (500). Coba lagi.',
          statusCode: 500,
          retryable: true,
        );
      default:
        if (server.isNotEmpty) return QrJoinFailure(server, statusCode: code);
        return QrJoinFailure(
          'Server menolak permintaan${code == null ? '' : ' ($code)'}. Coba lagi.',
          statusCode: code,
          retryable: true,
        );
    }
  }
}

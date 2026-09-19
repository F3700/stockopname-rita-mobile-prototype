import 'package:flutter_test/flutter_test.dart';
import 'package:stockopname_rita_mobile/core/network/qr_join_api.dart';

void main() {
  group('CoordinatorPreview.fromJson session_code toleran', () {
    Map<String, dynamic> base() => {
          'id': 12,
          'code': 'KOOR1',
          'inspector': 2,
          'rackAssigned': 5,
          'rackCompleted': 1,
          'status': 'IN_PROGRESS',
        };

    test('baca session_code snake_case (backend baru)', () {
      final p = CoordinatorPreview.fromJson(
          {...base(), 'session_code': 'SO-2026-01'});
      expect(p.sessionCode, 'SO-2026-01');
      expect(p.code, 'KOOR1');
    });

    test('baca sessionCode camelCase', () {
      final p = CoordinatorPreview.fromJson(
          {...base(), 'sessionCode': 'SO-2026-02'});
      expect(p.sessionCode, 'SO-2026-02');
    });

    test('tanpa key sesi (backend lama) -> string kosong', () {
      final p = CoordinatorPreview.fromJson(base());
      expect(p.sessionCode, '');
      expect(p.sessionLocation, '');
      expect(p.code, 'KOOR1');
      expect(p.id, 12);
    });

    test('baca sessionLocation camelCase', () {
      final p = CoordinatorPreview.fromJson(
          {...base(), 'sessionLocation': 'Gudang A'});
      expect(p.sessionLocation, 'Gudang A');
    });
  });

  group('CoordinatorPreview.isJoinable', () {
    CoordinatorPreview withStatus(String status) =>
        CoordinatorPreview.fromJson({
          'id': 5,
          'code': 'KOR-01',
          'status': status,
          'sessionCode': 'SESI-01',
          'sessionLocation': 'Gudang A',
        });

    test('IN_PROGRESS boleh lanjut', () {
      expect(withStatus('IN_PROGRESS').isJoinable, isTrue);
    });

    test('case-insensitive', () {
      expect(withStatus('in_progress').isJoinable, isTrue);
    });

    test('COMPLETED / kosong tidak boleh lanjut', () {
      expect(withStatus('COMPLETED').isJoinable, isFalse);
      expect(withStatus('').isJoinable, isFalse);
    });
  });
}

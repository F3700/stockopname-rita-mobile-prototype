import 'package:flutter_test/flutter_test.dart';
import 'package:stockopname_rita_mobile/core/qr/coor_qr.dart';

void main() {
  group('CoorQr.tryParseCoorQr', () {
    test('valid RITA-COOR-12 -> 12', () {
      expect(CoorQr.tryParseCoorQr('RITA-COOR-12'), 12);
    });

    test('trim spasi/newline', () {
      expect(CoorQr.tryParseCoorQr('  RITA-COOR-3  \n'), 3);
    });

    test('prefix case-insensitive', () {
      expect(CoorQr.tryParseCoorQr('rita-coor-7'), 7);
    });

    test('tolak format salah', () {
      expect(CoorQr.tryParseCoorQr(null), isNull);
      expect(CoorQr.tryParseCoorQr(''), isNull);
      expect(CoorQr.tryParseCoorQr('KOOR1'), isNull);
      expect(CoorQr.tryParseCoorQr('RITA-COOR-'), isNull);
      expect(CoorQr.tryParseCoorQr('RITA-COOR-0'), isNull);
      expect(CoorQr.tryParseCoorQr('RITA-COOR-abc'), isNull);
      expect(CoorQr.tryParseCoorQr('RITA-COOR-12-EXTRA'), isNull);
      expect(CoorQr.tryParseCoorQr('RITA-COOR--5'), isNull);
    });

    test('format round-trip', () {
      expect(CoorQr.format(12), 'RITA-COOR-12');
      expect(CoorQr.tryParseCoorQr(CoorQr.format(12)), 12);
    });
  });
}

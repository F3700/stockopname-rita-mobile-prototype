import 'package:flutter_test/flutter_test.dart';
import 'package:stockopname_rita_mobile/app.dart';

void main() {
  testWidgets('App menampilkan home stock scanner', (tester) async {
    await tester.pumpWidget(const RitaApp());
    // Satu frame cukup: teks statis langsung tampil tanpa menunggu
    // provider async (SQLite tidak tersedia di widget test).
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Stock Scanner'), findsOneWidget);
    expect(find.text('MULAI STOCK OPNAME'), findsOneWidget);
    expect(find.text('SCAN QR COORDINATOR'), findsOneWidget);
  });
}

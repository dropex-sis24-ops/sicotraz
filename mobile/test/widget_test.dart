import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('muestra la pantalla de preparación técnica', (tester) async {
    await tester.pumpWidget(const SicotrazApp());

    expect(find.text('SICOTRAZ'), findsOneWidget);
    expect(find.text('N° de ítem/contrato'), findsOneWidget);
  });
}

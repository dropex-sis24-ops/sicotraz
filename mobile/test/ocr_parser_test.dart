import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/ocr/application/local_ocr_service.dart';

void main() {
  const parser = OcrParser();
  const matcher = OcrCatalogMatcher();

  test('interpreta una lectura de Salas y normaliza el alias C.V.', () {
    final result = parser.parse('''
Código: 33367
Servicio: C.V.
Prenda | Cantidad
Sábanas Superiores | 40
Fundas: 40
''');
    final areas = [
      {
        'id': 1,
        'nombre': 'Cirugía Varones',
        'aliases': [
          {'alias_normalizado': 'CV'},
        ],
      },
    ];
    final clothes = [
      {'id': 10, 'nombre': 'Sábanas Superiores'},
      {'id': 11, 'nombre': 'Fundas'},
    ];

    expect(result.itemNumber, '33367');
    expect(matcher.areaId(result.rawText, areas), 1);
    expect(matcher.clothes(result.lines, clothes), {10: 40, 11: 40});
  });

  test('interpreta abreviaturas de prendas de Quirófano', () {
    final result = parser.parse('''
Servicio - Quirófano
Campo Grande (C. GRANDE) 30
F.M. - 5
Pijamas: 8
''');
    final clothes = [
      {'id': 20, 'nombre': 'Campo Grande (C. GRANDE)'},
      {'id': 21, 'nombre': 'F.M.'},
      {'id': 22, 'nombre': 'Pijamas'},
    ];

    expect(matcher.clothes(result.lines, clothes), {20: 30, 21: 5, 22: 8});
  });

  test('rechaza una imagen sin filas útiles', () {
    expect(
      () => parser.parse('foto borrosa sin cantidades'),
      throwsFormatException,
    );
  });
}

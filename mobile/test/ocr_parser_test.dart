import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/ocr/application/local_ocr_service.dart';

void main() {
  const parser = OcrParser();
  const matcher = OcrCatalogMatcher();

  test('interpreta una lectura de Salas y normaliza el alias C.V.', () {
    final result = parser.parse('''
Código: 33367
Servicio: C.V.
Fecha: 30/08/2026
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
    expect(result.templateName, 'Salas');
    expect(result.formDate, '30/08/2026');
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
    expect(result.templateName, 'Quirófano');
  });

  test('no asigna una prenda cuando la lectura es ambigua', () {
    final result = parser.parse('Sábanas 12\n');
    final clothes = [
      {'id': 10, 'nombre': 'Sábanas Superiores'},
      {'id': 11, 'nombre': 'Sábanas Inferiores'},
    ];

    final matched = matcher.clothesWithReview(result.lines, clothes);

    // Antes se asignaban las 12 unidades a la primera prenda parecida.
    expect(matched.quantities, isEmpty);
    expect(matched.unresolved.single.label, 'Sábanas');
    expect(matched.unresolved.single.quantity, 12);
    expect(matched.unresolved.single.candidates, [10, 11]);
  });

  test('suma dos líneas de la misma prenda en lugar de sobrescribirlas', () {
    final result = parser.parse('Fundas: 10\nFundas: 5\n');
    final clothes = [
      {'id': 11, 'nombre': 'Fundas'},
    ];

    expect(matcher.clothes(result.lines, clothes), {11: 15});
  });

  test('conserva los nombres de prenda con guion o varias palabras', () {
    final result = parser.parse('Cubre-camas 7\nFunda de Mayo 3\n');

    expect(result.lines.map((line) => line.label), [
      'Cubre-camas',
      'Funda de Mayo',
    ]);
    expect(result.lines.map((line) => line.quantity), [7, 3]);
  });

  test('no elige área cuando dos alias encajan igual de bien', () {
    final result = parser.parse('Servicio: Sala 1\nFundas: 4\n');
    final areas = [
      {'id': 1, 'nombre': 'Sala 1', 'aliases': <dynamic>[]},
      {'id': 2, 'nombre': 'Sala 10', 'aliases': <dynamic>[]},
    ];

    // "sala1" está contenido en "sala10": asignar el lote a la primera área
    // del catálogo movería stock del servicio equivocado.
    expect(matcher.areaId(result.rawText, areas), 1);
    expect(matcher.areaId('Servicio: Sala 10\nFundas: 4\n', areas), 2);
  });

  test('rechaza una imagen sin filas útiles', () {
    expect(
      () => parser.parse('foto borrosa sin cantidades'),
      throwsFormatException,
    );
  });

  test('detecta la plantilla aun antes de interpretar cantidades', () {
    expect(
      parser.detectTemplate('Formulario de entrega - Quirófano\nFunda Mayo'),
      'Quirófano',
    );
    expect(
      parser.detectTemplate('Formulario de entrega - Salas\nCubrecamas'),
      'Salas',
    );
  });
}

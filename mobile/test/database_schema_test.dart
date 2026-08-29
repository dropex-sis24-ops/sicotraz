import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/local_db/database_schema.dart';

void main() {
  test('el esquema local incluye las 15 tablas de negocio', () {
    const tables = [
      'rol',
      'usuario',
      'area',
      'alias_area',
      'tipo_prenda',
      'stock_area',
      'plantilla_formulario',
      'lote',
      'detalle_lote',
      'movimiento_lote',
      'verificacion_stock',
      'detalle_verificacion_stock',
      'alerta',
      'baja',
      'conflicto_sincronizacion',
    ];

    expect(DatabaseSchema.statements, hasLength(tables.length));
    for (final table in tables) {
      expect(
        DatabaseSchema.statements.any(
          (statement) => statement.contains('CREATE TABLE $table ('),
        ),
        isTrue,
        reason: 'Falta la tabla $table en el esquema SQLite.',
      );
    }
  });
}

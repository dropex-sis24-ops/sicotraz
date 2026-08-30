import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/local_db/database_schema.dart';

void main() {
  test('el esquema local incluye negocio, cola offline y caché', () {
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
      'pendiente_sincronizacion',
      'cache_api',
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
    final usuario = DatabaseSchema.statements.firstWhere(
      (statement) => statement.contains('CREATE TABLE usuario ('),
    );
    expect(usuario, contains('area_id INTEGER'));
    final queue = DatabaseSchema.statements.firstWhere(
      (statement) =>
          statement.contains('CREATE TABLE pendiente_sincronizacion ('),
    );
    expect(queue, contains('uuid_local TEXT NOT NULL UNIQUE'));
    expect(queue, contains('fecha_ultima_modificacion TEXT NOT NULL'));
  });
}

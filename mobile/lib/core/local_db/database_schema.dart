/// Esquema SQLite local de SICOTRAZ.
/// Debe mantenerse alineado con las migraciones Laravel del proyecto.
class DatabaseSchema {
  DatabaseSchema._();

  static const version = 1;

  static const statements = <String>[
    '''CREATE TABLE rol (
      id INTEGER PRIMARY KEY,
      nombre TEXT NOT NULL,
      created_at TEXT,
      updated_at TEXT
    )''',
    '''CREATE TABLE usuario (
      id INTEGER PRIMARY KEY,
      nombre TEXT NOT NULL,
      numero_item TEXT NOT NULL,
      carnet_identidad TEXT NOT NULL,
      password_hash TEXT NOT NULL,
      rol_id INTEGER NOT NULL,
      activo INTEGER NOT NULL DEFAULT 1,
      debe_cambiar_password INTEGER NOT NULL DEFAULT 0,
      intentos_fallidos INTEGER NOT NULL DEFAULT 0,
      bloqueado_hasta TEXT,
      created_at TEXT,
      updated_at TEXT,
      FOREIGN KEY (rol_id) REFERENCES rol(id)
    )''',
    '''CREATE TABLE area (
      id INTEGER PRIMARY KEY,
      nombre TEXT NOT NULL,
      activo INTEGER NOT NULL DEFAULT 1,
      created_at TEXT,
      updated_at TEXT
    )''',
    '''CREATE TABLE alias_area (
      id INTEGER PRIMARY KEY,
      area_id INTEGER NOT NULL,
      alias_normalizado TEXT NOT NULL,
      activo INTEGER NOT NULL DEFAULT 1,
      created_at TEXT,
      updated_at TEXT,
      FOREIGN KEY (area_id) REFERENCES area(id)
    )''',
    '''CREATE TABLE tipo_prenda (
      id INTEGER PRIMARY KEY,
      nombre TEXT NOT NULL,
      activo INTEGER NOT NULL DEFAULT 1,
      created_at TEXT,
      updated_at TEXT
    )''',
    '''CREATE TABLE stock_area (
      id INTEGER PRIMARY KEY,
      area_id INTEGER NOT NULL,
      tipo_prenda_id INTEGER NOT NULL,
      cantidad_total INTEGER NOT NULL DEFAULT 0 CHECK (cantidad_total BETWEEN 0 AND 999),
      cantidad_en_area INTEGER NOT NULL DEFAULT 0 CHECK (cantidad_en_area BETWEEN 0 AND 999),
      cantidad_en_lavanderia INTEGER NOT NULL DEFAULT 0 CHECK (cantidad_en_lavanderia BETWEEN 0 AND 999),
      FOREIGN KEY (area_id) REFERENCES area(id),
      FOREIGN KEY (tipo_prenda_id) REFERENCES tipo_prenda(id)
    )''',
    '''CREATE TABLE plantilla_formulario (
      id INTEGER PRIMARY KEY,
      nombre TEXT NOT NULL,
      estructura_campos TEXT NOT NULL,
      activo INTEGER NOT NULL DEFAULT 1,
      created_at TEXT,
      updated_at TEXT
    )''',
    '''CREATE TABLE lote (
      id INTEGER PRIMARY KEY,
      area_id INTEGER NOT NULL,
      etapa TEXT NOT NULL,
      fecha_hora TEXT NOT NULL,
      peso_kg REAL NOT NULL,
      usuario_entrega_id INTEGER NOT NULL,
      usuario_registra_id INTEGER NOT NULL,
      usuario_recibe_id INTEGER,
      origen_registro TEXT NOT NULL,
      plantilla_id INTEGER,
      nombre_quien_trae TEXT,
      sincronizado INTEGER NOT NULL DEFAULT 0,
      fecha_ultima_modificacion TEXT NOT NULL,
      created_at TEXT,
      updated_at TEXT,
      FOREIGN KEY (area_id) REFERENCES area(id),
      FOREIGN KEY (usuario_entrega_id) REFERENCES usuario(id),
      FOREIGN KEY (usuario_registra_id) REFERENCES usuario(id),
      FOREIGN KEY (usuario_recibe_id) REFERENCES usuario(id),
      FOREIGN KEY (plantilla_id) REFERENCES plantilla_formulario(id)
    )''',
    '''CREATE TABLE detalle_lote (
      id INTEGER PRIMARY KEY,
      lote_id INTEGER NOT NULL,
      tipo_prenda_id INTEGER NOT NULL,
      cantidad INTEGER NOT NULL CHECK (cantidad BETWEEN 0 AND 999),
      created_at TEXT,
      updated_at TEXT,
      FOREIGN KEY (lote_id) REFERENCES lote(id),
      FOREIGN KEY (tipo_prenda_id) REFERENCES tipo_prenda(id)
    )''',
    '''CREATE TABLE movimiento_lote (
      id INTEGER PRIMARY KEY,
      lote_id INTEGER NOT NULL,
      etapa TEXT NOT NULL,
      fecha_hora TEXT NOT NULL,
      usuario_id INTEGER NOT NULL,
      created_at TEXT,
      updated_at TEXT,
      FOREIGN KEY (lote_id) REFERENCES lote(id),
      FOREIGN KEY (usuario_id) REFERENCES usuario(id)
    )''',
    '''CREATE TABLE verificacion_stock (
      id INTEGER PRIMARY KEY,
      area_id INTEGER NOT NULL,
      usuario_id INTEGER NOT NULL,
      fecha_hora TEXT NOT NULL,
      resultado TEXT NOT NULL,
      observacion TEXT,
      sincronizado INTEGER NOT NULL DEFAULT 0,
      fecha_ultima_modificacion TEXT NOT NULL,
      created_at TEXT,
      updated_at TEXT,
      FOREIGN KEY (area_id) REFERENCES area(id),
      FOREIGN KEY (usuario_id) REFERENCES usuario(id)
    )''',
    '''CREATE TABLE detalle_verificacion_stock (
      id INTEGER PRIMARY KEY,
      verificacion_stock_id INTEGER NOT NULL,
      tipo_prenda_id INTEGER NOT NULL,
      cantidad_esperada INTEGER NOT NULL CHECK (cantidad_esperada BETWEEN 0 AND 999),
      cantidad_contada INTEGER NOT NULL CHECK (cantidad_contada BETWEEN 0 AND 999),
      created_at TEXT,
      updated_at TEXT,
      FOREIGN KEY (verificacion_stock_id) REFERENCES verificacion_stock(id),
      FOREIGN KEY (tipo_prenda_id) REFERENCES tipo_prenda(id)
    )''',
    '''CREATE TABLE alerta (
      id INTEGER PRIMARY KEY,
      area_id INTEGER NOT NULL,
      tipo_prenda_id INTEGER NOT NULL,
      usuario_reporta_id INTEGER NOT NULL,
      fecha_hora_reporte TEXT NOT NULL,
      descripcion TEXT NOT NULL,
      foto_evidencia_url TEXT,
      estado TEXT NOT NULL,
      usuario_resuelve_id INTEGER,
      fecha_resolucion TEXT,
      nota_resolucion TEXT,
      sincronizado INTEGER NOT NULL DEFAULT 0,
      fecha_ultima_modificacion TEXT NOT NULL,
      created_at TEXT,
      updated_at TEXT,
      FOREIGN KEY (area_id) REFERENCES area(id),
      FOREIGN KEY (tipo_prenda_id) REFERENCES tipo_prenda(id),
      FOREIGN KEY (usuario_reporta_id) REFERENCES usuario(id),
      FOREIGN KEY (usuario_resuelve_id) REFERENCES usuario(id)
    )''',
    '''CREATE TABLE baja (
      id INTEGER PRIMARY KEY,
      tipo_prenda_id INTEGER NOT NULL,
      area_id INTEGER NOT NULL,
      usuario_costura_id INTEGER NOT NULL,
      cantidad INTEGER NOT NULL CHECK (cantidad BETWEEN 0 AND 999),
      motivo TEXT NOT NULL,
      foto_evidencia_url TEXT,
      fecha_hora TEXT NOT NULL,
      sincronizado INTEGER NOT NULL DEFAULT 0,
      fecha_ultima_modificacion TEXT NOT NULL,
      created_at TEXT,
      updated_at TEXT,
      FOREIGN KEY (tipo_prenda_id) REFERENCES tipo_prenda(id),
      FOREIGN KEY (area_id) REFERENCES area(id),
      FOREIGN KEY (usuario_costura_id) REFERENCES usuario(id)
    )''',
    '''CREATE TABLE conflicto_sincronizacion (
      id INTEGER PRIMARY KEY,
      entidad_tipo TEXT NOT NULL,
      entidad_id INTEGER NOT NULL,
      version_local_json TEXT NOT NULL,
      version_servidor_json TEXT NOT NULL,
      estado TEXT NOT NULL,
      version_elegida TEXT,
      resuelto_por_id INTEGER,
      fecha_resolucion TEXT,
      created_at TEXT,
      updated_at TEXT,
      FOREIGN KEY (resuelto_por_id) REFERENCES usuario(id)
    )''',
  ];
}

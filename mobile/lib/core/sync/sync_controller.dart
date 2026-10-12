import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../local_db/local_database.dart';
import '../network/api_exception.dart';
import '../network/authenticated_api_client.dart';

enum SyncState { online, offline, syncing }

class SyncSubmitResult {
  const SyncSubmitResult({required this.queued, this.response});
  final bool queued;
  final dynamic response;
}

class SyncController extends ChangeNotifier {
  SyncController({AuthenticatedApiClient? api})
    : _api = api ?? AuthenticatedApiClient();

  final AuthenticatedApiClient _api;
  Timer? _timer;
  String? _token;
  static const maxIntentos = 5;

  SyncState state = SyncState.online;
  int pendingCount = 0;
  int conflictCount = 0;
  int stuckCount = 0;
  List<String> rejected = const [];
  bool _running = false;

  Future<void> start(String token, {int? areaId}) async {
    if (_token == token && _timer != null) return;
    _token = token;
    _timer?.cancel();
    await refreshCounts();
    unawaited(_warmCache(areaId));
    unawaited(synchronize());
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(synchronize()),
    );
  }

  Future<void> _warmCache(int? assignedAreaId) async {
    try {
      final areas =
          (await cachedGet('/catalogo/areas', cacheKey: 'catalogo_areas')
              as List<dynamic>);
      await cachedGet('/catalogo/prendas', cacheKey: 'catalogo_prendas');
      for (final raw in areas) {
        final area = raw as Map<String, dynamic>;
        if (area['activo'] == true) {
          final id = area['id'] as int;
          try {
            await cachedGet(
              '/catalogo/prendas?area_id=$id',
              cacheKey: 'catalogo_prendas_area_$id',
            );
            await cachedGet(
              '/lotes/formulario?area_id=$id',
              cacheKey: 'formulario_area_$id',
            );
          } catch (_) {
            // El rol actual puede no tener acceso al registro de lotes.
          }
        }
      }
      if (assignedAreaId != null) {
        await cachedGet(
          '/stock/verificacion?area_id=$assignedAreaId',
          cacheKey: 'stock_verificacion_$assignedAreaId',
        );
      }
    } catch (_) {
      // La siguiente recuperación automática volverá a intentar precargar.
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _token = null;
    rejected = const [];
  }

  /// Borra la caché y la cola del dispositivo al cambiar de usuario: de lo
  /// contrario el siguiente turno sincronizaba registros ajenos con su token y
  /// veía datos de áreas que no le corresponden.
  Future<void> clearDeviceData() async {
    stop();
    final db = await LocalDatabase.instance;
    await db.delete('cache_api');
    await db.delete('pendiente_sincronizacion');
    pendingCount = 0;
    stuckCount = 0;
    conflictCount = 0;
    state = SyncState.online;
    notifyListeners();
  }

  Future<SyncSubmitResult> submit({
    required String entityType,
    required String path,
    required Map<String, dynamic> payload,
    File? photo,
    String photoCategory = 'alertas',
  }) async {
    final token = _token;
    if (token == null) throw StateError('No existe una sesión activa.');
    // El identificador se fija aquí, antes del primer intento, y acompaña al
    // registro tanto en línea como en la cola. Así, si la respuesta se pierde
    // por un corte de red, el servidor reconoce el reenvío como el mismo
    // registro en lugar de crear un duplicado con su doble descuento de stock.
    final uuidLocal = _uuid();
    final identifiedPayload = {...payload, 'uuid_local': uuidLocal};
    try {
      final onlinePayload = Map<String, dynamic>.from(identifiedPayload);
      if (photo != null) {
        onlinePayload['foto_evidencia_url'] = await _api.uploadPhoto(
          token,
          photo,
          category: photoCategory,
        );
        // La foto ya está en el servidor: si el POST falla y el registro pasa
        // a la cola, se reutiliza esa URL en lugar de volver a subirla.
        identifiedPayload['foto_evidencia_url'] =
            onlinePayload['foto_evidencia_url'];
      }
      final response = await _api.post(path, token, onlinePayload);
      state = SyncState.online;
      notifyListeners();
      return SyncSubmitResult(queued: false, response: response);
    } on ApiException {
      rethrow;
    } catch (error) {
      final queuedPayload = Map<String, dynamic>.from(identifiedPayload);
      if (photo != null && !queuedPayload.containsKey('foto_evidencia_url')) {
        queuedPayload['_foto_local_path'] = photo.path;
        queuedPayload['_foto_categoria'] = photoCategory;
      }
      await _enqueue(uuidLocal, entityType, path, queuedPayload, '$error');
      state = SyncState.offline;
      await refreshCounts();
      return const SyncSubmitResult(queued: true);
    }
  }

  Future<dynamic> cachedGet(String path, {required String cacheKey}) async {
    final token = _token;
    final db = await LocalDatabase.instance;
    if (token != null) {
      try {
        final value = await _api.get(path, token);
        await db.insert('cache_api', {
          'clave': cacheKey,
          'datos_json': jsonEncode(value),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        state = SyncState.online;
        notifyListeners();
        return value;
      } on ApiException {
        rethrow;
      } catch (_) {
        state = SyncState.offline;
        notifyListeners();
      }
    }
    final cached = await db.query(
      'cache_api',
      where: 'clave = ?',
      whereArgs: [cacheKey],
      limit: 1,
    );
    if (cached.isEmpty) {
      throw const SocketException('No hay conexión ni datos locales todavía.');
    }
    return jsonDecode(cached.first['datos_json']! as String);
  }

  Future<void> synchronize() async {
    if (_running || _token == null) return;
    _running = true;
    try {
      final db = await LocalDatabase.instance;
      final pending = await db.query(
        'pendiente_sincronizacion',
        // Un registro que el servidor rechaza una y otra vez no debe frenar a
        // los demás ni reintentarse indefinidamente.
        where: 'intentos < ?',
        whereArgs: [maxIntentos],
        orderBy: 'id',
        limit: 100,
      );
      if (pending.isEmpty) {
        await _refreshConflicts();
        state = SyncState.online;
        return;
      }
      state = SyncState.syncing;
      notifyListeners();
      final records = <Map<String, dynamic>>[];
      for (final row in pending) {
        final payload =
            jsonDecode(row['datos_json']! as String) as Map<String, dynamic>;
        final photoPath = payload.remove('_foto_local_path') as String?;
        final category =
            payload.remove('_foto_categoria') as String? ?? 'alertas';
        if (photoPath != null &&
            payload['foto_evidencia_url'] == null &&
            File(photoPath).existsSync()) {
          payload['foto_evidencia_url'] = await _api.uploadPhoto(
            _token!,
            File(photoPath),
            category: category,
          );
          // Se recuerda la URL para no volver a subir la misma foto en cada
          // reintento y dejar copias huérfanas en el servidor.
          await db.update(
            'pendiente_sincronizacion',
            {
              'datos_json': jsonEncode({
                ...payload,
                '_foto_categoria': category,
              }),
            },
            where: 'uuid_local = ?',
            whereArgs: [row['uuid_local']],
          );
        }
        records.add({
          'tipo': row['entidad_tipo'],
          'uuid_local': row['uuid_local'],
          'fecha_ultima_modificacion': row['fecha_ultima_modificacion'],
          'datos': payload,
        });
      }
      final enviados = records
          .map((record) => record['uuid_local'] as String)
          .toList();
      final response =
          await _api.post('/sync', _token!, {'registros': records})
              as Map<String, dynamic>;
      final resueltos = <String>[
        ..._uuids(response['guardados']),
        ..._uuids(response['conflictos']),
        // El servidor rechazó el contenido: reintentarlo no cambiaría nada.
        ..._uuids(response['rechazados']),
      ];
      await _descartar(db, resueltos);
      await _registrarIntentoFallido(
        db,
        enviados.where((uuid) => !resueltos.contains(uuid)).toList(),
        'El servidor no confirmó el registro.',
      );
      rejected = _rechazos(response['rechazados']);
      conflictCount = (response['conflictos'] as List<dynamic>).length;
      await refreshCounts();
      await _refreshConflicts();
      state = SyncState.online;
    } on ApiException catch (error) {
      // Error del servidor sobre el lote completo (p. ej. token caducado):
      // se cuenta el intento para no girar en vacío cada 15 segundos.
      await _registrarIntentoFallido(
        await LocalDatabase.instance,
        null,
        error.message,
      );
      state = SyncState.online;
    } catch (_) {
      state = SyncState.offline;
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  List<String> _uuids(dynamic lista) => ((lista as List<dynamic>?) ?? [])
      .map((item) => (item as Map<String, dynamic>)['uuid_local'] as String)
      .toList();

  List<String> _rechazos(dynamic lista) => ((lista as List<dynamic>?) ?? [])
      .map(
        (item) =>
            (item as Map<String, dynamic>)['motivo'] as String? ??
            'Registro rechazado por el servidor.',
      )
      .toList();

  Future<void> _descartar(Database db, List<String> uuids) async {
    if (uuids.isEmpty) return;
    final marks = List.filled(uuids.length, '?').join(',');
    await db.delete(
      'pendiente_sincronizacion',
      where: 'uuid_local IN ($marks)',
      whereArgs: uuids,
    );
  }

  Future<void> _registrarIntentoFallido(
    Database db,
    List<String>? uuids,
    String error,
  ) async {
    if (uuids != null && uuids.isEmpty) return;
    await db.rawUpdate(
      'UPDATE pendiente_sincronizacion SET intentos = intentos + 1, '
      'ultimo_error = ?'
      '${uuids == null ? '' : ' WHERE uuid_local IN (${List.filled(uuids.length, '?').join(',')})'}',
      [error, ...?uuids],
    );
  }

  /// Registros que la cola dejó de reintentar y necesitan intervención manual.
  Future<List<Map<String, Object?>>> stuckRecords() async {
    final db = await LocalDatabase.instance;
    return db.query(
      'pendiente_sincronizacion',
      where: 'intentos >= ?',
      whereArgs: [maxIntentos],
      orderBy: 'id',
    );
  }

  Future<void> retryStuckRecords() async {
    final db = await LocalDatabase.instance;
    await db.update(
      'pendiente_sincronizacion',
      {'intentos': 0},
      where: 'intentos >= ?',
      whereArgs: [maxIntentos],
    );
    await refreshCounts();
    await synchronize();
  }

  Future<List<Map<String, dynamic>>> conflicts() async {
    final token = _token;
    if (token == null) throw StateError('No existe una sesión activa.');
    final value = await _api.get('/sync/conflictos', token);
    final list = (value as List<dynamic>).cast<Map<String, dynamic>>();
    conflictCount = list.length;
    notifyListeners();
    return list;
  }

  Future<void> resolveConflict(int id, String selected) async {
    final token = _token;
    if (token == null) throw StateError('No existe una sesión activa.');
    await _api.patch('/sync/conflictos/$id/resolver', token, {
      'version_elegida': selected,
    });
    await _refreshConflicts();
    notifyListeners();
  }

  Future<void> refreshCounts() async {
    final db = await LocalDatabase.instance;
    final result = await db.rawQuery(
      'SELECT '
      'SUM(CASE WHEN intentos < ? THEN 1 ELSE 0 END) AS pendientes, '
      'SUM(CASE WHEN intentos >= ? THEN 1 ELSE 0 END) AS atascados '
      'FROM pendiente_sincronizacion',
      [maxIntentos, maxIntentos],
    );
    pendingCount = (result.first['pendientes'] as int?) ?? 0;
    stuckCount = (result.first['atascados'] as int?) ?? 0;
    notifyListeners();
  }

  Future<void> _refreshConflicts() async {
    final token = _token;
    if (token == null) return;
    try {
      final value = await _api.get('/sync/conflictos', token);
      conflictCount = (value as List<dynamic>).length;
    } catch (_) {
      // Consultar los conflictos es informativo: su fallo no debe marcar la
      // sesión como desconectada ni abortar la sincronización.
    }
  }

  Future<void> _enqueue(
    String uuidLocal,
    String entityType,
    String path,
    Map<String, dynamic> payload,
    String error,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (await LocalDatabase.instance).insert('pendiente_sincronizacion', {
      'uuid_local': uuidLocal,
      'entidad_tipo': entityType,
      'ruta': path,
      'datos_json': jsonEncode(payload),
      'fecha_ultima_modificacion': now,
      'intentos': 0,
      'ultimo_error': error,
      'created_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  String _uuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

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
  SyncState state = SyncState.online;
  int pendingCount = 0;
  int conflictCount = 0;
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
    try {
      final onlinePayload = Map<String, dynamic>.from(payload);
      if (photo != null) {
        onlinePayload['foto_evidencia_url'] = await _api.uploadPhoto(
          token,
          photo,
          category: photoCategory,
        );
      }
      final response = await _api.post(path, token, onlinePayload);
      state = SyncState.online;
      notifyListeners();
      return SyncSubmitResult(queued: false, response: response);
    } on ApiException {
      rethrow;
    } catch (error) {
      final queuedPayload = Map<String, dynamic>.from(payload);
      if (photo != null) {
        queuedPayload['_foto_local_path'] = photo.path;
        queuedPayload['_foto_categoria'] = photoCategory;
      }
      await _enqueue(entityType, path, queuedPayload, '$error');
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
      final pending = await db.query('pendiente_sincronizacion', orderBy: 'id');
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
        if (photoPath != null && File(photoPath).existsSync()) {
          payload['foto_evidencia_url'] = await _api.uploadPhoto(
            _token!,
            File(photoPath),
            category: category,
          );
        }
        records.add({
          'tipo': row['entidad_tipo'],
          'uuid_local': row['uuid_local'],
          'fecha_ultima_modificacion': row['fecha_ultima_modificacion'],
          'datos': payload,
        });
      }
      final response =
          await _api.post('/sync', _token!, {'registros': records})
              as Map<String, dynamic>;
      final accepted =
          (response['guardados'] as List<dynamic>)
              .map(
                (item) =>
                    (item as Map<String, dynamic>)['uuid_local'] as String,
              )
              .toList()
            ..addAll(
              (response['conflictos'] as List<dynamic>).map(
                (item) =>
                    (item as Map<String, dynamic>)['uuid_local'] as String,
              ),
            );
      if (accepted.isNotEmpty) {
        final marks = List.filled(accepted.length, '?').join(',');
        await db.delete(
          'pendiente_sincronizacion',
          where: 'uuid_local IN ($marks)',
          whereArgs: accepted,
        );
      }
      conflictCount = (response['conflictos'] as List<dynamic>).length;
      await refreshCounts();
      await _refreshConflicts();
      state = SyncState.online;
    } on ApiException {
      state = SyncState.online;
    } catch (_) {
      state = SyncState.offline;
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> conflicts() async {
    final value = await _api.get('/sync/conflictos', _token!);
    final list = (value as List<dynamic>).cast<Map<String, dynamic>>();
    conflictCount = list.length;
    notifyListeners();
    return list;
  }

  Future<void> resolveConflict(int id, String selected) async {
    await _api.patch('/sync/conflictos/$id/resolver', _token!, {
      'version_elegida': selected,
    });
    await _refreshConflicts();
  }

  Future<void> refreshCounts() async {
    final db = await LocalDatabase.instance;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM pendiente_sincronizacion',
    );
    pendingCount = (result.first['total'] as int?) ?? 0;
    notifyListeners();
  }

  Future<void> _refreshConflicts() async {
    if (_token == null) return;
    final value = await _api.get('/sync/conflictos', _token!);
    conflictCount = (value as List<dynamic>).length;
  }

  Future<void> _enqueue(
    String entityType,
    String path,
    Map<String, dynamic> payload,
    String error,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (await LocalDatabase.instance).insert('pendiente_sincronizacion', {
      'uuid_local': _uuid(),
      'entidad_tipo': entityType,
      'ruta': path,
      'datos_json': jsonEncode(payload),
      'fecha_ultima_modificacion': now,
      'intentos': 0,
      'ultimo_error': error,
      'created_at': now,
    });
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

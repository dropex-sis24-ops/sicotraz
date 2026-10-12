import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/sync/sync_controller.dart';
import '../../auth/application/session_controller.dart';

class StockVerificationScreen extends StatefulWidget {
  const StockVerificationScreen({super.key});
  @override
  State<StockVerificationScreen> createState() =>
      _StockVerificationScreenState();
}

class _StockVerificationScreenState extends State<StockVerificationScreen> {
  int? _areaId;
  Future<List<dynamic>>? _stocks;
  final _note = TextEditingController();
  final Map<int, int> _counts = {};
  String? _result;
  bool _sending = false;
  late Future<List<dynamic>> _areas;

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionController>();
    _areaId = session.user?.areaId;
    _areas = _areaId == null
        ? context
              .read<SyncController>()
              .cachedGet('/catalogo/areas', cacheKey: 'catalogo_areas')
              .then((value) => value as List<dynamic>)
        : Future.value([]);
    if (_areaId != null) {
      _load();
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _load() {
    if (_areaId != null) {
      setState(
        () => _stocks = context
            .read<SyncController>()
            .cachedGet(
              '/stock/verificacion?area_id=$_areaId',
              cacheKey: 'stock_verificacion_$_areaId',
            )
            .then((v) => v as List<dynamic>),
      );
    }
  }

  Future<void> _submit(List<dynamic> stocks) async {
    final pendientes = stocks
        .map((raw) => (raw as Map<String, dynamic>)['tipo_prenda_id'] as int)
        .where((id) => !_counts.containsKey(id))
        .length;
    if (pendientes > 0) {
      setState(
        () => _result =
            'Falta contar $pendientes prenda(s). Escriba 0 si no encontró ninguna.',
      );
      return;
    }
    final details = stocks.map((raw) {
      final stock = raw as Map<String, dynamic>;
      final id = stock['tipo_prenda_id'] as int;
      return {'tipo_prenda_id': id, 'cantidad_contada': _counts[id]!};
    }).toList();
    setState(() {
      _sending = true;
      _result = null;
    });
    try {
      final submission = await context.read<SyncController>().submit(
        entityType: 'verificacion_stock',
        path: '/stock/verificacion',
        payload: {
          'area_id': _areaId,
          'observacion': _note.text.isEmpty ? null : _note.text,
          'detalles': details,
        },
      );
      if (mounted) {
        setState(() {
          _result = submission.queued
              ? 'Verificación guardada sin conexión; pendiente de sincronizar.'
              : _describirResultado(
                  (submission.response as Map<String, dynamic>)['resultado']
                      as String,
                );
          // Sin limpiar el formulario se podía registrar la misma
          // verificación varias veces seguidas.
          _counts.clear();
          _note.clear();
          _load();
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _result = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _result =
              'No fue posible registrar la verificación. '
              'Vuelva a intentarlo.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _describirResultado(String resultado) =>
      resultado == 'irregularidad_reportada'
      ? 'Registrada con diferencias respecto al stock del sistema.'
      : 'Registrada sin novedad: el conteo coincide con el sistema.';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Verificación de turno')),
    body: FutureBuilder<dynamic>(
      future: _areas,
      builder: (_, areas) {
        if (!areas.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = areas.data!;
        final assignedArea = context.read<SessionController>().user?.areaNombre;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_areaId != null)
              Text(
                'Área: ${assignedArea ?? 'asignada'}',
                style: Theme.of(context).textTheme.titleMedium,
              )
            else
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Área'),
                items: list.map((x) {
                  final m = x as Map<String, dynamic>;
                  return DropdownMenuItem(
                    value: m['id'] as int,
                    child: Text(m['nombre'] as String),
                  );
                }).toList(),
                onChanged: (v) {
                  setState(() {
                    _areaId = v;
                    // Los conteos pertenecen al área anterior.
                    _counts.clear();
                    _note.clear();
                    _result = null;
                  });
                  _load();
                },
              ),
            const SizedBox(height: 20),
            if (_stocks != null)
              FutureBuilder<List<dynamic>>(
                future: _stocks,
                builder: (_, s) {
                  if (!s.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final stocks = s.data!;
                  return Column(
                    children: [
                      for (final raw in stocks)
                        _Row(
                          data: raw as Map<String, dynamic>,
                          onChanged: (id, value) => _counts[id] = value,
                          onCleared: _counts.remove,
                        ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _note,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Observaciones (si hay diferencia)',
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _sending ? null : () => _submit(stocks),
                        child: Text(
                          _sending ? 'Registrando…' : 'Registrar conteo',
                        ),
                      ),
                      if (_result != null) Text(_result!),
                    ],
                  );
                },
              ),
          ],
        );
      },
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.data,
    required this.onChanged,
    required this.onCleared,
  });
  final Map<String, dynamic> data;
  final void Function(int, int) onChanged;
  final void Function(int) onCleared;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (data['tipo_prenda'] as Map<String, dynamic>?)?['nombre']
                    as String? ??
                'Prenda #${data['tipo_prenda_id']}',
          ),
          // La Pantalla 11 del documento maestro muestra "Esperado" junto al
          // conteo. Lo que no debe ocurrir es que ese valor se envíe solo:
          // el campo "Contado" es obligatorio (elemento 2 de la pantalla).
          Text('Esperado: ${data['cantidad_en_area']}'),
          const SizedBox(height: 10),
          TextField(
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: const InputDecoration(
              labelText: 'Contado',
              helperText: 'Cuente las prendas físicamente',
            ),
            onChanged: (value) {
              final cantidad = int.tryParse(value);
              if (cantidad == null) {
                onCleared(data['tipo_prenda_id'] as int);
              } else {
                onChanged(data['tipo_prenda_id'] as int, cantidad);
              }
            },
          ),
        ],
      ),
    ),
  );
}

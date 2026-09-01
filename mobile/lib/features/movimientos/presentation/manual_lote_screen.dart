import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/sync/sync_controller.dart';

class ManualLoteScreen extends StatefulWidget {
  const ManualLoteScreen({super.key, this.quirofanoOnly = false});
  final bool quirofanoOnly;

  @override
  State<ManualLoteScreen> createState() => _ManualLoteScreenState();
}

class _ManualLoteScreenState extends State<ManualLoteScreen> {
  final _peso = TextEditingController();
  final _itemEntrega = TextEditingController();
  final _nombreEntrega = TextEditingController();
  final _cantidades = <int, TextEditingController>{};
  late Future<List<dynamic>> _areas;
  Future<List<dynamic>>? _prendas;
  int? _areaId;
  String? _message;

  @override
  void initState() {
    super.initState();
    _areas = context
        .read<SyncController>()
        .cachedGet('/catalogo/areas', cacheKey: 'catalogo_areas')
        .then((value) {
          final areas = value as List<dynamic>;
          if (widget.quirofanoOnly && _areaId == null) {
            final quirofano = areas.cast<Map<String, dynamic>>().where(
              (area) => area['nombre'] == 'Quirófano',
            );
            if (quirofano.isNotEmpty) {
              _selectArea(quirofano.first['id'] as int);
            }
          }
          return areas;
        });
  }

  @override
  void dispose() {
    _peso.dispose();
    _itemEntrega.dispose();
    _nombreEntrega.dispose();
    for (final controller in _cantidades.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _selectArea(int? value) {
    if (value == null) return;
    for (final controller in _cantidades.values) {
      controller.dispose();
    }
    _cantidades.clear();
    setState(() {
      _areaId = value;
      _prendas = context
          .read<SyncController>()
          .cachedGet(
            '/lotes/formulario?area_id=$value',
            cacheKey: 'formulario_area_$value',
          )
          .then(
            (value) =>
                (value as Map<String, dynamic>)['prendas'] as List<dynamic>,
          );
    });
  }

  Future<void> _save(List<dynamic> prendas) async {
    if (_areaId == null) return;
    final details = prendas
        .map((raw) => raw as Map<String, dynamic>)
        .map((prenda) {
          final id = prenda['id'] as int;
          return {
            'tipo_prenda_id': id,
            'cantidad': int.tryParse(_cantidades[id]?.text ?? '') ?? 0,
          };
        })
        .where((detail) => (detail['cantidad'] as int) > 0)
        .toList();
    if (details.isEmpty || _peso.text.isEmpty) {
      setState(() => _message = 'Ingrese el peso y al menos una prenda.');
      return;
    }
    try {
      final submission = await context.read<SyncController>().submit(
        entityType: 'lote',
        path: '/lotes',
        payload: {
          'area_id': _areaId,
          'numero_item_entrega': _itemEntrega.text.trim().isEmpty
              ? null
              : _itemEntrega.text.trim(),
          'nombre_quien_trae': _nombreEntrega.text.trim().isEmpty
              ? null
              : _nombreEntrega.text.trim(),
          'peso_kg': double.parse(_peso.text.replaceAll(',', '.')),
          'detalles': details,
        },
      );
      if (mounted) {
        setState(() {
          if (submission.queued) {
            _message =
                'Sin conexión: lote guardado en el dispositivo y pendiente de sincronizar.';
          } else {
            final result = submission.response as Map<String, dynamic>;
            _message = 'Lote #${result['id']} guardado: ${result['etapa']}.';
          }
          _peso.clear();
          _itemEntrega.clear();
          _nombreEntrega.clear();
          for (final controller in _cantidades.values) {
            controller.clear();
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = '$error');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.quirofanoOnly ? 'Registrar Quirófano' : 'Registro manual',
      ),
    ),
    body: FutureBuilder<List<dynamic>>(
      future: _areas,
      builder: (_, areasSnapshot) {
        if (!areasSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final areas = areasSnapshot.data!
            .cast<Map<String, dynamic>>()
            .where(
              (area) =>
                  area['activo'] == true &&
                  (!widget.quirofanoOnly || area['nombre'] == 'Quirófano'),
            )
            .toList();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<int>(
              initialValue: _areaId,
              decoration: const InputDecoration(labelText: 'Servicio / Área'),
              items: areas
                  .map(
                    (area) => DropdownMenuItem(
                      value: area['id'] as int,
                      child: Text(area['nombre'] as String),
                    ),
                  )
                  .toList(),
              onChanged: _selectArea,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _itemEntrega,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: const InputDecoration(
                labelText: 'N° de ítem de quien entrega (opcional)',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nombreEntrega,
              decoration: const InputDecoration(
                labelText: 'Nombre de quien trae (opcional)',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _peso,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Peso total (kg)'),
            ),
            const SizedBox(height: 24),
            if (_prendas != null)
              FutureBuilder<List<dynamic>>(
                future: _prendas,
                builder: (_, prendasSnapshot) {
                  if (!prendasSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final prendas = prendasSnapshot.data!;
                  return Column(
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Prendas de esta área',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final raw in prendas)
                        Builder(
                          builder: (_) {
                            final prenda = raw as Map<String, dynamic>;
                            final id = prenda['id'] as int;
                            final controller = _cantidades.putIfAbsent(
                              id,
                              TextEditingController.new,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TextField(
                                controller: controller,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(3),
                                ],
                                decoration: InputDecoration(
                                  labelText: prenda['nombre'] as String,
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => _save(prendas),
                        child: const Text('Guardar lote'),
                      ),
                    ],
                  );
                },
              ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_message!),
              ),
          ],
        );
      },
    ),
  );
}

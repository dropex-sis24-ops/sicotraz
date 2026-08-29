import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/network/authenticated_api_client.dart';
import '../../auth/application/session_controller.dart';

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

  String get _token => context.read<SessionController>().token!;

  @override
  void initState() {
    super.initState();
    _areas = AuthenticatedApiClient()
        .get('/catalogo/areas', _token)
        .then((value) => value as List<dynamic>);
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
      _prendas = AuthenticatedApiClient()
          .get('/lotes/formulario?area_id=$value', _token)
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
      final result =
          await AuthenticatedApiClient().post('/lotes', _token, {
                'area_id': _areaId,
                'numero_item_entrega': _itemEntrega.text.trim().isEmpty
                    ? null
                    : _itemEntrega.text.trim(),
                'nombre_quien_trae': _nombreEntrega.text.trim().isEmpty
                    ? null
                    : _nombreEntrega.text.trim(),
                'peso_kg': double.parse(_peso.text.replaceAll(',', '.')),
                'detalles': details,
              })
              as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _message = 'Lote #${result['id']} guardado: ${result['etapa']}.';
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
            TextField(
              controller: _nombreEntrega,
              decoration: const InputDecoration(
                labelText: 'Nombre de quien trae (opcional)',
              ),
            ),
            TextField(
              controller: _peso,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Peso total (kg)'),
            ),
            const SizedBox(height: 16),
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
                        child: Text('Prendas de esta área'),
                      ),
                      for (final raw in prendas)
                        Builder(
                          builder: (_) {
                            final prenda = raw as Map<String, dynamic>;
                            final id = prenda['id'] as int;
                            final controller = _cantidades.putIfAbsent(
                              id,
                              TextEditingController.new,
                            );
                            return TextField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              decoration: InputDecoration(
                                labelText: prenda['nombre'] as String,
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

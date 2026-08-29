import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/network/authenticated_api_client.dart';
import '../../auth/application/session_controller.dart';

class StockLoadScreen extends StatefulWidget {
  const StockLoadScreen({super.key});
  @override
  State<StockLoadScreen> createState() => _StockLoadScreenState();
}

class _StockLoadScreenState extends State<StockLoadScreen> {
  final _cantidad = TextEditingController();
  int? _areaId, _prendaId;
  int _actual = 0;
  String? _message;
  late Future<List<dynamic>> _areas, _prendas;
  @override
  void initState() {
    super.initState();
    final api = AuthenticatedApiClient();
    final token = context.read<SessionController>().token!;
    _areas = api.get('/catalogo/areas', token).then((v) => v as List<dynamic>);
    _prendas = api
        .get('/catalogo/prendas', token)
        .then((v) => v as List<dynamic>);
  }

  @override
  void dispose() {
    _cantidad.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_areaId == null || _prendaId == null || _cantidad.text.isEmpty) return;
    try {
      await AuthenticatedApiClient().post(
        '/stock/carga-inicial',
        context.read<SessionController>().token!,
        {
          'area_id': _areaId,
          'tipo_prenda_id': _prendaId,
          'cantidad': int.parse(_cantidad.text),
        },
      );
      if (mounted) {
        setState(() {
          _actual += int.parse(_cantidad.text);
          _cantidad.clear();
          _message = 'Stock actualizado correctamente.';
        });
      }
    } catch (e) {
      setState(() => _message = '$e');
    }
  }

  Future<void> _loadCurrent() async {
    if (_areaId == null || _prendaId == null) return;
    try {
      final result =
          await AuthenticatedApiClient().get(
                '/stock/area?area_id=$_areaId',
                context.read<SessionController>().token!,
              )
              as List<dynamic>;
      final row = result.cast<Map<String, dynamic>>().where(
        (item) => item['tipo_prenda_id'] == _prendaId,
      );
      if (mounted) {
        setState(
          () => _actual = row.isEmpty ? 0 : row.first['cantidad_total'] as int,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _actual = 0);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Carga de stock')),
    body: FutureBuilder<List<dynamic>>(
      future: Future.wait([_areas, _prendas]).then((v) => v),
      builder: (_, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final areas = (s.data![0] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .where((area) => area['activo'] == true)
            .toList();
        final prendas = (s.data![1] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .where((prenda) => prenda['activo'] == true)
            .toList();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Área'),
              items: areas.map((m) {
                return DropdownMenuItem(
                  value: m['id'] as int,
                  child: Text(m['nombre'] as String),
                );
              }).toList(),
              onChanged: (v) {
                setState(() => _areaId = v);
                _loadCurrent();
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Tipo de prenda'),
              items: prendas.map((m) {
                return DropdownMenuItem(
                  value: m['id'] as int,
                  child: Text(m['nombre'] as String),
                );
              }).toList(),
              onChanged: (v) {
                setState(() => _prendaId = v);
                _loadCurrent();
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cantidad,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: const InputDecoration(
                labelText: 'Cantidad a agregar',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Text('Stock actual: $_actual'),
            Text(
              'Nuevo total: ${_actual + (int.tryParse(_cantidad.text) ?? 0)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_message!),
              ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Confirmar')),
          ],
        );
      },
    ),
  );
}

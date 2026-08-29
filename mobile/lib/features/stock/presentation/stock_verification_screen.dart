import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/network/authenticated_api_client.dart';
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
  late Future<List<dynamic>> _areas;

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionController>();
    _areaId = session.user?.areaId;
    _areas = _areaId == null
        ? AuthenticatedApiClient()
              .get('/catalogo/areas', session.token!)
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
        () => _stocks = AuthenticatedApiClient()
            .get(
              '/stock/verificacion?area_id=$_areaId',
              context.read<SessionController>().token!,
            )
            .then((v) => v as List<dynamic>),
      );
    }
  }

  Future<void> _submit(List<dynamic> stocks) async {
    final details = stocks.map((raw) {
      final stock = raw as Map<String, dynamic>;
      final id = stock['tipo_prenda_id'] as int;
      return {
        'tipo_prenda_id': id,
        'cantidad_contada': _counts[id] ?? stock['cantidad_en_area'],
      };
    }).toList();
    try {
      final response = await AuthenticatedApiClient().post(
        '/stock/verificacion',
        context.read<SessionController>().token!,
        {
          'observacion': _note.text.isEmpty ? null : _note.text,
          'detalles': details,
        },
      );
      if (mounted) {
        setState(
          () => _result =
              (response as Map<String, dynamic>)['resultado'] as String,
        );
      }
    } catch (error) {
      setState(() => _result = '$error');
    }
  }

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
                  _areaId = v;
                  _load();
                },
              ),
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
                        ),
                      TextField(
                        controller: _note,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Observaciones (si hay diferencia)',
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => _submit(stocks),
                        child: const Text('Registrar'),
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
  const _Row({required this.data, required this.onChanged});
  final Map<String, dynamic> data;
  final void Function(int, int) onChanged;
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
          Text('Esperado: ${data['cantidad_en_area']}'),
          TextField(
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: const InputDecoration(labelText: 'Contado'),
            onChanged: (value) => onChanged(
              data['tipo_prenda_id'] as int,
              int.tryParse(value) ?? 0,
            ),
          ),
        ],
      ),
    ),
  );
}

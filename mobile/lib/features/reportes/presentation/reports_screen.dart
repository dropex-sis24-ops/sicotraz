import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/authenticated_api_client.dart';
import '../../auth/application/session_controller.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _period = 'diario';
  late DateTime _from;
  late DateTime _to;
  bool _loading = true;
  Map<String, dynamic>? _processed;
  Map<String, dynamic>? _differences;
  String? _error;

  String get _token => context.read<SessionController>().token!;
  String _date(DateTime value) => value.toIso8601String().split('T').first;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month);
    _to = now;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = AuthenticatedApiClient();
      final query = 'desde=${_date(_from)}&hasta=${_date(_to)}';
      final values = await Future.wait([
        api.get('/reportes/cantidad-peso?$query&periodo=$_period', _token),
        api.get('/reportes/bajas-vs-faltantes?$query', _token),
      ]);
      if (mounted) {
        setState(() {
          _processed = values[0] as Map<String, dynamic>;
          _differences = values[1] as Map<String, dynamic>;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick(bool from) async {
    final value = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (value == null) return;
    setState(() {
      if (from) {
        _from = value;
      } else {
        _to = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reportes')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'diario', label: Text('Diario')),
            ButtonSegment(value: 'mensual', label: Text('Mensual')),
          ],
          selected: {_period},
          onSelectionChanged: (value) => setState(() => _period = value.first),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => _pick(true),
                child: Text('Desde ${_date(_from)}'),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: () => _pick(false),
                child: Text('Hasta ${_date(_to)}'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _loading ? null : _load,
          child: const Text('Consultar'),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_error != null) Text(_error!),
        if (_processed != null) ...[
          const SizedBox(height: 18),
          Text(
            'Cantidad y peso procesado',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          _ProcessedSummary(data: _processed!),
        ],
        if (_differences != null) ...[
          const SizedBox(height: 18),
          Text(
            'Bajas vs. faltantes',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          _DifferenceSummary(data: _differences!),
        ],
      ],
    ),
  );
}

class _ProcessedSummary extends StatelessWidget {
  const _ProcessedSummary({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final totals = data['totales'] as Map<String, dynamic>;
    final detail = data['detalle'] as List<dynamic>;
    return Column(
      children: [
        Card(
          child: ListTile(
            title: Text(
              '${totals['cantidad_prendas']} prendas · ${totals['peso_kg']} kg',
            ),
            subtitle: Text('${totals['lotes']} lotes'),
          ),
        ),
        for (final raw in detail)
          ListTile(
            title: Text((raw as Map<String, dynamic>)['periodo'] as String),
            trailing: Text(
              '${raw['cantidad_prendas']} pr. · ${raw['peso_kg']} kg',
            ),
          ),
      ],
    );
  }
}

class _DifferenceSummary extends StatelessWidget {
  const _DifferenceSummary({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final bajas = data['bajas_confirmadas'] as Map<String, dynamic>;
    final missing = data['faltantes_sin_resolver'] as Map<String, dynamic>;
    final areas = data['areas_con_disminucion'] as List<dynamic>;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: ListTile(
            title: Text('${bajas['cantidad']} bajas confirmadas'),
            subtitle: const Text('Descontadas permanentemente del stock'),
          ),
        ),
        Card(
          child: ListTile(
            title: Text('${missing['cantidad_alertas']} faltantes pendientes'),
            subtitle: const Text('No se suman a las bajas'),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Áreas con disminución frecuente'),
        for (final raw in areas)
          Builder(
            builder: (context) {
              final area = raw as Map<String, dynamic>;
              return ListTile(
                title: Text(area['area'] as String),
                subtitle: Text(
                  'Bajas: ${area['bajas_confirmadas']} · Faltantes: ${area['faltantes_pendientes']}',
                ),
              );
            },
          ),
      ],
    );
  }
}

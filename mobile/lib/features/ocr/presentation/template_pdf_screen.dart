import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../core/network/authenticated_api_client.dart';
import '../../auth/application/session_controller.dart';

class TemplatePdfScreen extends StatefulWidget {
  const TemplatePdfScreen({super.key});

  @override
  State<TemplatePdfScreen> createState() => _TemplatePdfScreenState();
}

class _TemplatePdfScreenState extends State<TemplatePdfScreen> {
  String _template = 'Salas';
  int? _areaId;
  late Future<List<dynamic>> _areas;
  bool _generating = false;
  String? _message;

  String get _token => context.read<SessionController>().token!;

  @override
  void initState() {
    super.initState();
    _areas = AuthenticatedApiClient()
        .get('/catalogo/areas', _token)
        .then((value) => value as List<dynamic>);
  }

  Future<void> _print() async {
    setState(() {
      _generating = true;
      _message = null;
    });
    try {
      final area = _template == 'Salas' && _areaId != null
          ? '&area_id=$_areaId'
          : '';
      final bytes = await AuthenticatedApiClient().download(
        '/plantillas/pdf?plantilla=${Uri.encodeQueryComponent(_template)}$area',
        _token,
      );
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (error) {
      if (mounted) setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Imprimir plantilla en blanco')),
    body: FutureBuilder<List<dynamic>>(
      future: _areas,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Salas', label: Text('Salas')),
                ButtonSegment(value: 'Quirófano', label: Text('Quirófano')),
              ],
              selected: {_template},
              onSelectionChanged: (value) => setState(() {
                _template = value.first;
                if (_template == 'Quirófano') _areaId = null;
              }),
            ),
            if (_template == 'Salas') ...[
              const SizedBox(height: 20),
              DropdownButtonFormField<int?>(
                initialValue: _areaId,
                decoration: const InputDecoration(
                  labelText: 'Área preimpresa (opcional)',
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Dejar en blanco'),
                  ),
                  ...snapshot.data!.cast<Map<String, dynamic>>().map(
                    (area) => DropdownMenuItem(
                      value: area['id'] as int,
                      child: Text(area['nombre'] as String),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _areaId = value),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _generating ? null : _print,
              icon: const Icon(Icons.print),
              label: Text(
                _generating ? 'Generando…' : 'Generar e imprimir PDF',
              ),
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_message!),
              ),
          ],
        );
      },
    ),
  );
}

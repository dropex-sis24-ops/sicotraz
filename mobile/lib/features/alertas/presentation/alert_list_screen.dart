import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/authenticated_api_client.dart';
import '../../auth/application/session_controller.dart';

class AlertListScreen extends StatefulWidget {
  const AlertListScreen({super.key});

  @override
  State<AlertListScreen> createState() => _AlertListScreenState();
}

class _AlertListScreenState extends State<AlertListScreen> {
  late Future<List<dynamic>> _alerts;
  String get _token => context.read<SessionController>().token!;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _alerts = AuthenticatedApiClient()
        .get('/alertas?estado=pendiente', _token)
        .then(
          (value) => (value as Map<String, dynamic>)['data'] as List<dynamic>,
        );
  }

  Future<void> _resolve(Map<String, dynamic> alert) async {
    final note = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolver alerta'),
        content: TextField(
          controller: note,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Nota de resolución (opcional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, note.text.trim()),
            child: const Text('Resolver'),
          ),
        ],
      ),
    );
    note.dispose();
    if (result == null) return;
    await AuthenticatedApiClient().patch(
      '/alertas/${alert['id']}/resolver',
      _token,
      {'nota_resolucion': result.isEmpty ? null : result},
    );
    if (!mounted) return;
    setState(_reload);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Alerta resuelta.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Alertas pendientes')),
    body: FutureBuilder<List<dynamic>>(
      future: _alerts,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final alerts = snapshot.data!;
        if (alerts.isEmpty) {
          return const Center(child: Text('No hay alertas pendientes.'));
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: ListView.builder(
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index] as Map<String, dynamic>;
              final area = alert['area'] as Map<String, dynamic>?;
              final prenda = alert['tipo_prenda'] as Map<String, dynamic>?;
              return Card(
                child: ListTile(
                  title: Text(
                    '${area?['nombre'] ?? 'Área'} — ${prenda?['nombre'] ?? 'Prenda'}',
                  ),
                  subtitle: Text(alert['descripcion'] as String),
                  trailing: FilledButton(
                    onPressed: () => _resolve(alert),
                    child: const Text('Resolver'),
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

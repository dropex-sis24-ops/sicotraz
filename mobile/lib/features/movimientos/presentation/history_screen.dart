import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/authenticated_api_client.dart';
import '../../auth/application/session_controller.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<dynamic>> _lotes;
  String get _token => context.read<SessionController>().token!;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _lotes = AuthenticatedApiClient()
        .get('/historial', _token)
        .then(
          (value) => (value as Map<String, dynamic>)['data'] as List<dynamic>,
        );
  }

  bool get _canManage {
    final role = context.read<SessionController>().user?.rol;
    return role == 'Ropera' || role == 'Encargado de Ropería y Lavandería';
  }

  Future<void> _advance(Map<String, dynamic> lot) async {
    await AuthenticatedApiClient().patch('/lotes/${lot['id']}/etapa', _token, {
      'etapa': 'en_lavado',
    });
    if (!mounted) return;
    setState(_reload);
  }

  Future<void> _deliver(Map<String, dynamic> lot) async {
    final item = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar entrega limpia'),
        content: TextField(
          controller: item,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'N° de ítem de quien recibe (opcional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await AuthenticatedApiClient().post(
        '/lotes/${lot['id']}/entrega-limpia',
        _token,
        {
          'numero_item_recibe': item.text.trim().isEmpty
              ? null
              : item.text.trim(),
        },
      );
      if (mounted) setState(_reload);
    }
    item.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Historial de lotes')),
    body: FutureBuilder<List<dynamic>>(
      future: _lotes,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final lots = snapshot.data!;
        if (lots.isEmpty) {
          return const Center(child: Text('Aún no hay lotes registrados.'));
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: ListView.builder(
            itemCount: lots.length,
            itemBuilder: (context, index) {
              final lot = lots[index] as Map<String, dynamic>;
              final area = lot['area'] as Map<String, dynamic>?;
              final details = (lot['detalles'] as List<dynamic>? ?? [])
                  .map((item) {
                    final detail = item as Map<String, dynamic>;
                    final cloth =
                        detail['tipo_prenda'] as Map<String, dynamic>?;
                    return '${cloth?['nombre'] ?? 'Prenda'}: ${detail['cantidad']}';
                  })
                  .join(', ');
              final stage = lot['etapa'] as String;
              return Card(
                child: ListTile(
                  title: Text(
                    'Lote #${lot['id']} — ${area?['nombre'] ?? 'Área'}',
                  ),
                  subtitle: Text(
                    '$details\nEtapa: ${lot['etapa']} · ${lot['peso_kg']} kg',
                  ),
                  isThreeLine: true,
                  trailing: !_canManage || stage == 'limpio_entregado'
                      ? null
                      : PopupMenuButton<String>(
                          onSelected: (action) async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              if (action == 'lavado') await _advance(lot);
                              if (action == 'entrega') await _deliver(lot);
                            } catch (error) {
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text('$error')),
                                );
                              }
                            }
                          },
                          itemBuilder: (_) => [
                            if (stage == 'sucio_recibido')
                              const PopupMenuItem(
                                value: 'lavado',
                                child: Text('Pasar a lavado'),
                              ),
                            if (stage == 'en_lavado')
                              const PopupMenuItem(
                                value: 'entrega',
                                child: Text('Entregar limpio'),
                              ),
                          ],
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

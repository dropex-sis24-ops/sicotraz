import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/sync/sync_controller.dart';
import '../../auth/application/session_controller.dart';

class ConflictScreen extends StatefulWidget {
  const ConflictScreen({super.key});

  @override
  State<ConflictScreen> createState() => _ConflictScreenState();
}

class _ConflictScreenState extends State<ConflictScreen> {
  late Future<List<Map<String, dynamic>>> _conflicts;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _conflicts = context.read<SyncController>().conflicts();
  }

  Future<void> _resolve(int id, String selected) async {
    await context.read<SyncController>().resolveConflict(id, selected);
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final role = context.read<SessionController>().user?.rol;
    final canResolve =
        role == 'Super Admin' || role == 'Encargado de Ropería y Lavandería';
    return Scaffold(
      appBar: AppBar(title: const Text('Conflictos de sincronización')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _conflicts,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('No fue posible cargar: ${snapshot.error}'),
            );
          }
          final conflicts = snapshot.data!;
          if (conflicts.isEmpty) {
            return const Center(child: Text('No hay conflictos pendientes.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: conflicts.length,
            itemBuilder: (context, index) {
              final item = conflicts[index];
              return Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.warning_amber),
                  title: Text('${item['entidad_tipo']} #${item['entidad_id']}'),
                  subtitle: const Text('Se conservaron las dos versiones'),
                  childrenPadding: const EdgeInsets.all(16),
                  children: [
                    _Version(
                      title: 'Registro A — dispositivo',
                      value: item['version_local_json'],
                    ),
                    _Version(
                      title: 'Registro B — servidor',
                      value: item['version_servidor_json'],
                    ),
                    if (canResolve)
                      Wrap(
                        spacing: 10,
                        children: [
                          OutlinedButton(
                            onPressed: () =>
                                _resolve(item['id'] as int, 'servidor'),
                            child: const Text('Conservar servidor'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                _resolve(item['id'] as int, 'local'),
                            child: const Text('Conservar dispositivo'),
                          ),
                        ],
                      )
                    else
                      const Text(
                        'Un Encargado o Super Admin debe decidir cuál conservar.',
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Version extends StatelessWidget {
  const _Version({required this.title, required this.value});
  final String title;
  final dynamic value;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        SelectableText(const JsonEncoder.withIndent('  ').convert(value)),
      ],
    ),
  );
}

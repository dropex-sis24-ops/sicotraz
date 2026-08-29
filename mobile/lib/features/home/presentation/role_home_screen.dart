import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/application/session_controller.dart';

class RoleHomeScreen extends StatelessWidget {
  const RoleHomeScreen({super.key});

  static const _actions = {
    'Super Admin': ['Dashboard', 'Gestión de usuarios', 'Gestión de catálogo'],
    'Encargado de Ropería y Lavandería': [
      'Lista del día',
      'Alertas pendientes',
      'Seguimiento de lotes',
      'Dashboard',
    ],
    'Ropera': ['Registrar Quirófano', 'Capturar formulario', 'Registro manual'],
    'Personal manual': ['Ver última lista', 'Reportar'],
    'Costura': ['Dar de baja prenda', 'Mis bajas recientes'],
  };

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user!;
    final actions = _actions[user.rol] ?? const <String>[];

    return Scaffold(
      appBar: AppBar(
        title: Text('SICOTRAZ — ${user.rol}'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<SessionController>().logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Hola, ${user.nombre}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Chip(
            avatar: Icon(Icons.cloud_done, size: 18),
            label: Text('Conexión disponible'),
          ),
          const SizedBox(height: 16),
          for (final action in actions)
            Card(
              child: ListTile(
                title: Text(action),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '$action se implementará en su módulo correspondiente.',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

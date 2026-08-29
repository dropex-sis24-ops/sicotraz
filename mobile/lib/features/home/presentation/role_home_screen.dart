import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/application/session_controller.dart';
import '../../admin/presentation/catalog_management_screen.dart';
import '../../admin/presentation/user_management_screen.dart';
import '../../alertas/presentation/alert_form_screen.dart';
import '../../alertas/presentation/alert_list_screen.dart';
import '../../movimientos/presentation/history_screen.dart';
import '../../movimientos/presentation/manual_lote_screen.dart';
import '../../ocr/presentation/capture_form_screen.dart';
import '../../ocr/presentation/template_pdf_screen.dart';
import '../../stock/presentation/stock_load_screen.dart';
import '../../stock/presentation/stock_verification_screen.dart';

class RoleHomeScreen extends StatelessWidget {
  const RoleHomeScreen({super.key});

  static const _actions = {
    'Super Admin': [
      'Dashboard',
      'Gestión de usuarios',
      'Gestión de catálogo',
      'Carga de stock inicial',
      'Imprimir plantilla',
    ],
    'Encargado de Ropería y Lavandería': [
      'Lista del día',
      'Alertas pendientes',
      'Seguimiento de lotes',
      'Dashboard',
      'Imprimir plantilla',
    ],
    'Ropera': [
      'Registrar Quirófano',
      'Capturar formulario',
      'Registro manual',
      'Alertas pendientes',
    ],
    'Personal manual': ['Verificar turno', 'Ver última lista', 'Reportar'],
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
                onTap: () {
                  if (action == 'Carga de stock inicial') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const StockLoadScreen(),
                      ),
                    );
                  } else if (action == 'Gestión de usuarios') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const UserManagementScreen(),
                      ),
                    );
                  } else if (action == 'Gestión de catálogo') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CatalogManagementScreen(),
                      ),
                    );
                  } else if (action == 'Verificar turno') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const StockVerificationScreen(),
                      ),
                    );
                  } else if (action == 'Registro manual') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ManualLoteScreen(),
                      ),
                    );
                  } else if (action == 'Registrar Quirófano') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const ManualLoteScreen(quirofanoOnly: true),
                      ),
                    );
                  } else if (action == 'Capturar formulario') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CaptureFormScreen(),
                      ),
                    );
                  } else if (action == 'Imprimir plantilla') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TemplatePdfScreen(),
                      ),
                    );
                  } else if (action == 'Reportar') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AlertFormScreen(),
                      ),
                    );
                  } else if (action == 'Alertas pendientes') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AlertListScreen(),
                      ),
                    );
                  } else if (action == 'Lista del día' ||
                      action == 'Seguimiento de lotes' ||
                      action == 'Ver última lista') {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    );
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

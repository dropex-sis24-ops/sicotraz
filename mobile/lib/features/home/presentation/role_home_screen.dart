import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/application/session_controller.dart';
import '../../admin/presentation/catalog_management_screen.dart';
import '../../admin/presentation/user_management_screen.dart';
import '../../alertas/presentation/alert_form_screen.dart';
import '../../alertas/presentation/alert_list_screen.dart';
import '../../costura/presentation/baja_form_screen.dart';
import '../../costura/presentation/recent_bajas_screen.dart';
import '../../movimientos/presentation/history_screen.dart';
import '../../movimientos/presentation/manual_lote_screen.dart';
import '../../ocr/presentation/capture_form_screen.dart';
import '../../ocr/presentation/template_pdf_screen.dart';
import '../../reportes/presentation/dashboard_screen.dart';
import '../../reportes/presentation/reports_screen.dart';
import '../../stock/presentation/stock_load_screen.dart';
import '../../stock/presentation/stock_verification_screen.dart';
import '../../../core/sync/sync_controller.dart';
import '../../sync/presentation/conflict_screen.dart';

class RoleHomeScreen extends StatefulWidget {
  const RoleHomeScreen({super.key});

  @override
  State<RoleHomeScreen> createState() => _RoleHomeScreenState();
}

class _RoleHomeScreenState extends State<RoleHomeScreen> {
  static const _actions = {
    'Super Admin': [
      'Dashboard',
      'Gestión de usuarios',
      'Gestión de catálogo',
      'Carga de stock inicial',
      'Imprimir plantilla',
      'Reportes',
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<SessionController>().token;
      if (token != null) {
        context.read<SyncController>().start(
          token,
          areaId: context.read<SessionController>().user?.areaId,
        );
      }
    });
  }

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
            onPressed: () {
              context.read<SyncController>().stop();
              context.read<SessionController>().logout();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Hola, ${user.nombre}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (context.watch<SyncController>().conflictCount > 0)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber),
                      title: Text(
                        '${context.watch<SyncController>().conflictCount} conflicto(s) de sincronización',
                      ),
                      subtitle: const Text('Se conservaron ambas versiones.'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ConflictScreen(),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                if (user.rol == 'Ropera') ...[
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CaptureFormScreen(),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.document_scanner_outlined,
                              size: 56,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Capturar formulario con OCR',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Fotografíe una lista de Salas o Quirófano y revise los datos antes de guardar.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const CaptureFormScreen(),
                                ),
                              ),
                              icon: const Icon(Icons.photo_camera),
                              label: const Text('Iniciar captura OCR'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Otras opciones',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                ],
                for (final action in actions.where(
                  (action) =>
                      user.rol != 'Ropera' || action != 'Capturar formulario',
                ))
                  Card(
                    child: ListTile(
                      title: Text(
                        user.rol == 'Ropera' && action == 'Registrar Quirófano'
                            ? 'Registrar Quirófano manual'
                            : action,
                      ),
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
                        } else if (action == 'Dar de baja prenda') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const BajaFormScreen(),
                            ),
                          );
                        } else if (action == 'Mis bajas recientes') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RecentBajasScreen(),
                            ),
                          );
                        } else if (action == 'Dashboard') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DashboardScreen(),
                            ),
                          );
                        } else if (action == 'Reportes') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ReportsScreen(),
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
                            MaterialPageRoute(
                              builder: (_) => const HistoryScreen(),
                            ),
                          );
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

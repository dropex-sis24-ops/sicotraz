import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/authenticated_api_client.dart';
import '../../auth/application/session_controller.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<Map<String, dynamic>> _dashboard;
  String get _token => context.read<SessionController>().token!;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _dashboard = AuthenticatedApiClient()
        .get('/dashboard', _token)
        .then((value) => value as Map<String, dynamic>);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Dashboard')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _dashboard,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final topArea = data['area_mas_alertas_mes'] as Map<String, dynamic>?;
        final topCloth = data['prenda_mas_bajas_mes'] as Map<String, dynamic>?;
        final cards = [
          (
            'Alertas pendientes hoy',
            '${data['alertas_pendientes_hoy']}',
            Icons.warning_amber,
          ),
          (
            'Lavado esta semana',
            '${data['lavado_semana_cantidad']} prendas',
            Icons.local_laundry_service,
          ),
          (
            'Lavado este mes',
            '${data['lavado_mes_cantidad']} prendas',
            Icons.calendar_month,
          ),
          ('Bajas este mes', '${data['bajas_mes']} prendas', Icons.content_cut),
          ('Ropa circulando', '${data['ropa_circulando']} prendas', Icons.sync),
          (
            'Área con más alertas',
            topArea == null
                ? 'Sin registros'
                : '${topArea['nombre']} (${topArea['cantidad']})',
            Icons.apartment,
          ),
          (
            'Prenda con más bajas',
            topCloth == null
                ? 'Sin registros'
                : '${topCloth['nombre']} (${topCloth['cantidad']})',
            Icons.checkroom,
          ),
        ];
        final areas = data['totales_por_area'] as List<dynamic>;
        return RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GridView.count(
                crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 3 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.35,
                children: [
                  for (final card in cards)
                    _MetricCard(title: card.$1, value: card.$2, icon: card.$3),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Control de stock por área',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final raw in areas)
                Builder(
                  builder: (context) {
                    final area = raw as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        title: Text(area['area'] as String),
                        subtitle: Text(
                          'En área: ${area['cantidad_en_area']} · En lavandería: ${area['cantidad_en_lavanderia']}',
                        ),
                        trailing: Text('${area['cantidad_total']} total'),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(title, textAlign: TextAlign.center, maxLines: 2),
        ],
      ),
    ),
  );
}

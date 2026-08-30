import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/authenticated_api_client.dart';
import '../../auth/application/session_controller.dart';

class RecentBajasScreen extends StatefulWidget {
  const RecentBajasScreen({super.key});

  @override
  State<RecentBajasScreen> createState() => _RecentBajasScreenState();
}

class _RecentBajasScreenState extends State<RecentBajasScreen> {
  late Future<List<dynamic>> _bajas;
  String get _token => context.read<SessionController>().token!;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _bajas = AuthenticatedApiClient()
        .get('/bajas', _token)
        .then(
          (value) => (value as Map<String, dynamic>)['data'] as List<dynamic>,
        );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mis bajas recientes')),
    body: FutureBuilder<List<dynamic>>(
      future: _bajas,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Center(child: Text('No hay bajas registradas.'));
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final baja = snapshot.data![index] as Map<String, dynamic>;
              final area = baja['area'] as Map<String, dynamic>?;
              final cloth = baja['tipo_prenda'] as Map<String, dynamic>?;
              return Card(
                child: ListTile(
                  title: Text(
                    '${cloth?['nombre'] ?? 'Prenda'} × ${baja['cantidad']}',
                  ),
                  subtitle: Text(
                    '${area?['nombre'] ?? 'Área'}\n${baja['motivo']}',
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

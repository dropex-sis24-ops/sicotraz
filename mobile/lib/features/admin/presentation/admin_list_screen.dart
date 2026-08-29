import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/authenticated_api_client.dart';
import '../../auth/application/session_controller.dart';

class AdminListScreen extends StatefulWidget {
  const AdminListScreen({super.key, required this.title, required this.path});
  final String title;
  final String path;
  @override
  State<AdminListScreen> createState() => _AdminListScreenState();
}

class _AdminListScreenState extends State<AdminListScreen> {
  late Future<dynamic> _data;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _data = AuthenticatedApiClient().get(
      widget.path,
      context.read<SessionController>().token!,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: FutureBuilder<dynamic>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final raw = snapshot.data;
        final items = raw is Map<String, dynamic>
            ? raw['data'] as List<dynamic>
            : raw as List<dynamic>;
        return RefreshIndicator(
          onRefresh: () async {
            setState(_load);
            await _data;
          },
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, index) {
              final item = items[index] as Map<String, dynamic>;
              return ListTile(
                title: Text(item['nombre'] as String),
                subtitle: Text(
                  item['numero_item']?.toString() ??
                      (item['activo'] == true ? 'Activo' : 'Inactivo'),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

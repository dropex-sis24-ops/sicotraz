import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/authenticated_api_client.dart';
import '../../auth/application/session_controller.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  static const _roles = [
    'Super Admin',
    'Encargado de Ropería y Lavandería',
    'Ropera',
    'Personal manual',
    'Costura',
  ];
  final _search = TextEditingController();
  late Future<List<dynamic>> _users;

  String get _token => context.read<SessionController>().token!;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    _users = AuthenticatedApiClient()
        .get(
          '/usuarios?buscar=${Uri.encodeQueryComponent(_search.text)}',
          _token,
        )
        .then(
          (value) => (value as Map<String, dynamic>)['data'] as List<dynamic>,
        );
  }

  Future<void> _showForm([Map<String, dynamic>? user]) async {
    final areas =
        await AuthenticatedApiClient().get('/catalogo/areas', _token)
            as List<dynamic>;
    if (!mounted) {
      return;
    }
    final name = TextEditingController(text: user?['nombre'] as String? ?? '');
    final item = TextEditingController(
      text: user?['numero_item']?.toString() ?? '',
    );
    final carnet = TextEditingController();
    String role =
        (user?['rol'] as Map<String, dynamic>?)?['nombre'] as String? ??
        _roles.first;
    int? areaId = (user?['area_id'] as num?)?.toInt();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialog) => AlertDialog(
          title: Text(user == null ? 'Nuevo usuario' : 'Editar usuario'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                  ),
                ),
                TextField(
                  controller: item,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'N° de ítem/contrato',
                  ),
                ),
                if (user == null)
                  TextField(
                    controller: carnet,
                    decoration: const InputDecoration(
                      labelText: 'Carnet de identidad (contraseña inicial)',
                    ),
                  ),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Rol'),
                  items: _roles
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) => setDialog(() => role = value!),
                ),
                if (role == 'Personal manual')
                  DropdownButtonFormField<int>(
                    initialValue: areaId,
                    decoration: const InputDecoration(
                      labelText: 'Área asignada',
                    ),
                    items: areas
                        .where(
                          (raw) =>
                              (raw as Map<String, dynamic>)['activo'] == true,
                        )
                        .map((raw) {
                          final area = raw as Map<String, dynamic>;
                          return DropdownMenuItem(
                            value: area['id'] as int,
                            child: Text(area['nombre'] as String),
                          );
                        })
                        .toList(),
                    onChanged: (value) => setDialog(() => areaId = value),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final roleId = _roles.indexOf(role) + 1;
                try {
                  final data = <String, dynamic>{
                    'nombre': name.text.trim(),
                    'numero_item': item.text.trim(),
                    'rol_id': roleId,
                    'area_id': role == 'Personal manual' ? areaId : null,
                  };
                  if (user == null) {
                    data['carnet_identidad'] = carnet.text.trim();
                  }
                  if (user == null) {
                    await AuthenticatedApiClient().post(
                      '/usuarios',
                      _token,
                      data,
                    );
                  } else {
                    await AuthenticatedApiClient().put(
                      '/usuarios/${user['id']}',
                      _token,
                      data,
                    );
                  }
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                } catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(
                      dialogContext,
                    ).showSnackBar(SnackBar(content: Text('$error')));
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    item.dispose();
    carnet.dispose();
    if (saved == true && mounted) {
      setState(_reload);
    }
  }

  Future<void> _action(Map<String, dynamic> user, String action) async {
    final id = user['id'];
    if (action == 'Desactivar') {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Desactivar cuenta'),
          content: const Text(
            'La cuenta ya no podrá iniciar sesión. El historial se conservará.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Desactivar'),
            ),
          ],
        ),
      );
      if (accepted != true) return;
    }
    final path = switch (action) {
      'Desactivar' => '/usuarios/$id/desactivar',
      'Reactivar' => '/usuarios/$id/reactivar',
      'Desbloquear' => '/usuarios/$id/desbloquear',
      _ => '/usuarios/$id/resetear-password',
    };
    try {
      if (action == 'Resetear contraseña') {
        await AuthenticatedApiClient().post(path, _token);
      } else {
        await AuthenticatedApiClient().patch(path, _token);
      }
      if (mounted) {
        setState(_reload);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Gestión de usuarios')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _showForm,
      icon: const Icon(Icons.person_add),
      label: const Text('Nuevo usuario'),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              labelText: 'Buscar por nombre o ítem',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => setState(_reload),
              ),
            ),
            onSubmitted: (_) => setState(_reload),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _users,
            builder: (_, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return RefreshIndicator(
                onRefresh: () async {
                  setState(_reload);
                  await _users;
                },
                child: ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (_, index) {
                    final user = snapshot.data![index] as Map<String, dynamic>;
                    final active = user['activo'] == true;
                    final role =
                        (user['rol'] as Map<String, dynamic>?)?['nombre'] ?? '';
                    return Opacity(
                      opacity: active ? 1 : .55,
                      child: Card(
                        child: ListTile(
                          title: Text('${user['nombre']} · $role'),
                          subtitle: Text(
                            'Ítem: ${user['numero_item']} · ${active ? 'Activo' : 'Inactivo'}',
                          ),
                          onTap: active ? () => _showForm(user) : null,
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) => _action(user, value),
                            itemBuilder: (_) => [
                              if (active)
                                const PopupMenuItem(
                                  value: 'Desactivar',
                                  child: Text('Desactivar'),
                                ),
                              if (!active)
                                const PopupMenuItem(
                                  value: 'Reactivar',
                                  child: Text('Reactivar'),
                                ),
                              const PopupMenuItem(
                                value: 'Desbloquear',
                                child: Text('Desbloquear'),
                              ),
                              const PopupMenuItem(
                                value: 'Resetear contraseña',
                                child: Text('Resetear contraseña'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

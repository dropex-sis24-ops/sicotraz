import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/authenticated_api_client.dart';
import '../../auth/application/session_controller.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _api = AuthenticatedApiClient();
  final _search = TextEditingController();
  final List<dynamic> _items = [];
  // Los identificadores de rol se leen del servidor: deducirlos de la posición
  // en una lista fija del cliente asignaba el rol equivocado si los ids de la
  // tabla no eran 1..5 en ese mismo orden.
  List<Map<String, dynamic>> _roles = const [];
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;

  String? get _token => context.read<SessionController>().token;

  @override
  void initState() {
    super.initState();
    _loadRoles();
    _load(reset: true);
  }

  Future<void> _loadRoles() async {
    final token = _token;
    if (token == null) return;
    try {
      final roles = await _api.get('/catalogo/roles', token) as List<dynamic>;
      if (mounted) {
        setState(() => _roles = roles.cast<Map<String, dynamic>>());
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No fue posible cargar los roles. '
              'Revise su conexión antes de crear usuarios.',
        );
      }
    }
  }

  Future<void> _load({bool reset = false}) async {
    final token = _token;
    if (token == null || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _page = 1;
        _hasMore = true;
      }
    });
    try {
      final body =
          await _api.get(
                '/usuarios?page=$_page&per_page=20'
                '&buscar=${Uri.encodeQueryComponent(_search.text)}',
                token,
              )
              as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _items.addAll(body['data'] as List<dynamic>);
        _hasMore = body['next_page_url'] != null;
        if (_hasMore) _page++;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No fue posible cargar los usuarios.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _showForm([Map<String, dynamic>? user]) async {
    final token = _token;
    if (token == null) return;
    if (_roles.isEmpty) {
      await _loadRoles();
      if (!mounted || _roles.isEmpty) return;
    }
    final areas = await _api.get('/catalogo/areas', token) as List<dynamic>;
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
        _roles.first['nombre'] as String;
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
                const SizedBox(height: 14),
                TextField(
                  controller: item,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'N° de ítem/contrato',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: carnet,
                  decoration: InputDecoration(
                    labelText: user == null
                        ? 'Carnet de identidad (contraseña inicial)'
                        : 'Nuevo carnet de identidad (opcional)',
                    helperText: user == null
                        ? null
                        : 'Si lo cambia, la contraseña volverá a ser el nuevo carnet.',
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Rol'),
                  items: _roles
                      .map(
                        (rol) => DropdownMenuItem(
                          value: rol['nombre'] as String,
                          child: Text(rol['nombre'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialog(() => role = value!),
                ),
                if (role == 'Personal manual') const SizedBox(height: 14),
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
                final roleId =
                    _roles.firstWhere((rol) => rol['nombre'] == role)['id']
                        as int;
                try {
                  final data = <String, dynamic>{
                    'nombre': name.text.trim(),
                    'numero_item': item.text.trim(),
                    'rol_id': roleId,
                    'area_id': role == 'Personal manual' ? areaId : null,
                  };
                  if (carnet.text.trim().isNotEmpty) {
                    data['carnet_identidad'] = carnet.text.trim();
                  }
                  if (user == null) {
                    await _api.post('/usuarios', token, data);
                  } else {
                    await _api.put('/usuarios/${user['id']}', token, data);
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
      await _load(reset: true);
    }
  }

  Future<void> _action(Map<String, dynamic> user, String action) async {
    final token = _token;
    if (token == null) return;
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
    if (!mounted) return;
    if (action == 'Eliminar') {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Eliminar usuario definitivamente'),
          content: const Text(
            'Solo se podrá eliminar si todavía no tiene lotes, alertas, bajas ni otro historial. Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar'),
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
      if (action == 'Eliminar') {
        await _api.delete('/usuarios/$id', token);
      } else if (action == 'Resetear contraseña') {
        await _api.post(path, token);
      } else {
        await _api.patch(path, token);
      }
      if (mounted) {
        await _load(reset: true);
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
                onPressed: () => _load(reset: true),
              ),
            ),
            onSubmitted: (_) => _load(reset: true),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: Builder(
            builder: (_) {
              if (_items.isEmpty) {
                if (_loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                return const Center(
                  child: Text('No hay usuarios que mostrar.'),
                );
              }
              return RefreshIndicator(
                onRefresh: () => _load(reset: true),
                child: ListView.builder(
                  // Antes solo se leía la primera página: a partir del usuario
                  // 21 las cuentas eran invisibles e imposibles de administrar.
                  itemCount: _items.length + (_hasMore ? 1 : 0),
                  itemBuilder: (_, index) {
                    if (index == _items.length) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: _loading
                              ? const CircularProgressIndicator()
                              : OutlinedButton(
                                  onPressed: _load,
                                  child: const Text('Cargar más usuarios'),
                                ),
                        ),
                      );
                    }
                    final user = _items[index] as Map<String, dynamic>;
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
                          onTap: () => _showForm(user),
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
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'Eliminar',
                                child: Text('Eliminar definitivamente'),
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

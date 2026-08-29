import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/authenticated_api_client.dart';
import '../../auth/application/session_controller.dart';

class CatalogManagementScreen extends StatefulWidget {
  const CatalogManagementScreen({super.key});

  @override
  State<CatalogManagementScreen> createState() =>
      _CatalogManagementScreenState();
}

class _CatalogManagementScreenState extends State<CatalogManagementScreen> {
  late Future<List<dynamic>> _prendas;
  late Future<List<dynamic>> _areas;
  late Future<List<dynamic>> _plantillas;
  String get _token => context.read<SessionController>().token!;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final api = AuthenticatedApiClient();
    _prendas = api
        .get('/catalogo/prendas', _token)
        .then((value) => value as List<dynamic>);
    _areas = api
        .get('/catalogo/areas', _token)
        .then((value) => value as List<dynamic>);
    _plantillas = api
        .get('/catalogo/plantillas', _token)
        .then((value) => value as List<dynamic>);
  }

  Future<void> _editNamed({
    required String title,
    required String basePath,
    Map<String, dynamic>? item,
  }) async {
    final controller = TextEditingController(
      text: item?['nombre'] as String? ?? '',
    );
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                if (item == null) {
                  await AuthenticatedApiClient().post(basePath, _token, {
                    'nombre': controller.text.trim(),
                  });
                } else {
                  await AuthenticatedApiClient().patch(
                    '$basePath/${item['id']}',
                    _token,
                    {'nombre': controller.text.trim()},
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
    );
    controller.dispose();
    if (result == true && mounted) {
      setState(_reload);
    }
  }

  Future<void> _toggle(String path, Map<String, dynamic> item) async {
    await AuthenticatedApiClient().patch('$path/${item['id']}', _token, {
      'activo': item['activo'] != true,
    });
    if (mounted) {
      setState(_reload);
    }
  }

  Future<void> _editAlias(
    Map<String, dynamic> area, [
    Map<String, dynamic>? alias,
  ]) async {
    final controller = TextEditingController(
      text: alias?['alias_normalizado'] as String? ?? '',
    );
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          alias == null ? 'Alias para ${area['nombre']}' : 'Editar alias',
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Alias reconocible'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                if (alias == null) {
                  await AuthenticatedApiClient().post(
                    '/catalogo/areas/${area['id']}/alias',
                    _token,
                    {'alias': controller.text.trim()},
                  );
                } else {
                  await AuthenticatedApiClient().patch(
                    '/catalogo/alias/${alias['id']}',
                    _token,
                    {'alias': controller.text.trim()},
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
          if (alias != null)
            TextButton(
              onPressed: () async {
                await AuthenticatedApiClient().patch(
                  '/catalogo/alias/${alias['id']}',
                  _token,
                  {'activo': alias['activo'] != true},
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: Text(alias['activo'] == true ? 'Desactivar' : 'Reactivar'),
            ),
        ],
      ),
    );
    controller.dispose();
    if (result == true && mounted) {
      setState(_reload);
    }
  }

  Future<void> _editTemplate(Map<String, dynamic> template) async {
    final controller = TextEditingController(
      text: const JsonEncoder.withIndent(
        '  ',
      ).convert(template['estructura_campos']),
    );
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Plantilla ${template['nombre']}'),
        content: TextField(
          controller: controller,
          maxLines: 10,
          decoration: const InputDecoration(labelText: 'Estructura JSON'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final structure = jsonDecode(controller.text);
                if (structure is! Map && structure is! List) {
                  throw const FormatException(
                    'Debe ser un objeto o lista JSON.',
                  );
                }
                await AuthenticatedApiClient().patch(
                  '/catalogo/plantillas/${template['id']}',
                  _token,
                  {'estructura_campos': structure},
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Estructura inválida: $error')),
                  );
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == true && mounted) {
      setState(_reload);
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de catálogo'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Prendas'),
            Tab(text: 'Áreas/Alias'),
            Tab(text: 'Plantillas'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          _NamedList(
            future: _prendas,
            onAdd: () => _editNamed(
              title: 'Nueva prenda',
              basePath: '/catalogo/prendas',
            ),
            onEdit: (item) => _editNamed(
              title: 'Editar prenda',
              basePath: '/catalogo/prendas',
              item: item,
            ),
            onToggle: (item) => _toggle('/catalogo/prendas', item),
          ),
          _AreasList(
            future: _areas,
            onAdd: () =>
                _editNamed(title: 'Nueva área', basePath: '/catalogo/areas'),
            onEdit: (item) => _editNamed(
              title: 'Editar área',
              basePath: '/catalogo/areas',
              item: item,
            ),
            onToggle: (item) => _toggle('/catalogo/areas', item),
            onAlias: _editAlias,
          ),
          _TemplatesList(
            future: _plantillas,
            onEdit: _editTemplate,
            onToggle: (item) => _toggle('/catalogo/plantillas', item),
          ),
        ],
      ),
    ),
  );
}

class _NamedList extends StatelessWidget {
  const _NamedList({
    required this.future,
    required this.onAdd,
    required this.onEdit,
    required this.onToggle,
  });
  final Future<List<dynamic>> future;
  final VoidCallback onAdd;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onToggle;
  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future: future,
    builder: (_, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Nuevo'),
          ),
          for (final raw in snapshot.data!)
            _CatalogTile(
              item: raw as Map<String, dynamic>,
              onEdit: onEdit,
              onToggle: onToggle,
            ),
        ],
      );
    },
  );
}

class _AreasList extends StatelessWidget {
  const _AreasList({
    required this.future,
    required this.onAdd,
    required this.onEdit,
    required this.onToggle,
    required this.onAlias,
  });
  final Future<List<dynamic>> future;
  final VoidCallback onAdd;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onToggle;
  final Future<void> Function(Map<String, dynamic>, [Map<String, dynamic>?])
  onAlias;
  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future: future,
    builder: (_, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Nueva área'),
          ),
          for (final raw in snapshot.data!)
            Builder(
              builder: (_) {
                final area = raw as Map<String, dynamic>;
                final aliases = (area['aliases'] as List<dynamic>? ?? [])
                    .cast<Map<String, dynamic>>();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(area['nombre'] as String),
                          subtitle: Text(
                            area['activo'] == true ? 'Activo' : 'Inactivo',
                          ),
                          onTap: () => onEdit(area),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) => value == 'alias'
                                ? onAlias(area)
                                : onToggle(area),
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'alias',
                                child: Text('Agregar alias'),
                              ),
                              PopupMenuItem(
                                value: 'toggle',
                                child: Text(
                                  area['activo'] == true
                                      ? 'Desactivar'
                                      : 'Reactivar',
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (aliases.isEmpty) const Text('Sin alias'),
                        Wrap(
                          spacing: 6,
                          children: [
                            for (final alias in aliases)
                              ActionChip(
                                label: Text(
                                  alias['alias_normalizado'] as String,
                                ),
                                onPressed: () => onAlias(area, alias),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      );
    },
  );
}

class _TemplatesList extends StatelessWidget {
  const _TemplatesList({
    required this.future,
    required this.onEdit,
    required this.onToggle,
  });
  final Future<List<dynamic>> future;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onToggle;
  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future: future,
    builder: (_, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Solo se editan las dos plantillas definidas para el sistema.',
          ),
          for (final raw in snapshot.data!)
            _CatalogTile(
              item: raw as Map<String, dynamic>,
              onEdit: onEdit,
              onToggle: onToggle,
            ),
        ],
      );
    },
  );
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({
    required this.item,
    required this.onEdit,
    required this.onToggle,
  });
  final Map<String, dynamic> item;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onToggle;
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: item['activo'] == true ? 1 : .55,
    child: Card(
      child: ListTile(
        title: Text(item['nombre'] as String),
        subtitle: Text(item['activo'] == true ? 'Activo' : 'Inactivo'),
        onTap: () => onEdit(item),
        trailing: PopupMenuButton<String>(
          onSelected: (_) => onToggle(item),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'toggle',
              child: Text(item['activo'] == true ? 'Desactivar' : 'Reactivar'),
            ),
          ],
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/authenticated_api_client.dart';
import '../../../core/sync/sync_controller.dart';
import '../../auth/application/session_controller.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _api = AuthenticatedApiClient();
  final List<dynamic> _lots = [];
  // Antes solo se leía la primera página: un lote antiguo sin cerrar quedaba
  // fuera de la lista y su stock inmovilizado sin forma de recuperarlo.
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  String? _stage;
  String? _error;

  // Pantalla 15: el filtro es por trabajador o por área, nunca ambos a la vez.
  _FilterKind _kind = _FilterKind.area;
  int? _areaId;
  int? _workerId;
  DateTimeRange? _range;
  List<dynamic> _areas = const [];
  List<dynamic> _workers = const [];

  static const _stages = {
    null: 'Todas las etapas',
    'sucio_recibido': 'Sucio recibido',
    'en_lavado': 'En lavado',
    'limpio_entregado': 'Limpio entregado',
  };

  String? get _token => context.read<SessionController>().token;

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _loadMore(reset: true);
  }

  Future<void> _loadFilters() async {
    final token = _token;
    if (token == null) return;
    // El listado de usuarios es exclusivo del Super Admin: para el resto el
    // filtro por trabajador no se ofrece.
    final esSuperAdmin =
        context.read<SessionController>().user?.rol == 'Super Admin';
    final sync = context.read<SyncController>();
    try {
      final areas = await sync.cachedGet(
        '/catalogo/areas',
        cacheKey: 'catalogo_areas',
      );
      if (mounted) setState(() => _areas = areas as List<dynamic>);
    } catch (_) {
      // Sin catálogo se puede seguir consultando sin filtrar por área.
    }
    if (!esSuperAdmin) return;
    try {
      final body = await _api.get('/usuarios?per_page=100', token);
      if (mounted) {
        setState(
          () => _workers =
              (body as Map<String, dynamic>)['data'] as List<dynamic>,
        );
      }
    } catch (_) {
      // Igual que arriba: el filtro simplemente no aparece.
    }
  }

  Future<void> _loadMore({bool reset = false}) async {
    final token = _token;
    if (token == null || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _lots.clear();
        _page = 1;
        _hasMore = true;
      }
    });
    try {
      final query = [
        'page=$_page',
        'per_page=20',
        if (_stage != null) 'etapa=$_stage',
        if (_kind == _FilterKind.area && _areaId != null) 'area_id=$_areaId',
        if (_kind == _FilterKind.worker && _workerId != null)
          'trabajador_id=$_workerId',
        if (_range != null) 'desde=${_fecha(_range!.start)}',
        if (_range != null) 'hasta=${_fecha(_range!.end)}',
      ].join('&');
      final body =
          await _api.get('/historial?$query', token) as Map<String, dynamic>;
      final data = body['data'] as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _lots.addAll(data);
        _hasMore = body['next_page_url'] != null;
        if (_hasMore) _page++;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No fue posible cargar el historial. '
              'Revise su conexión.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _fecha(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  Future<void> _pickRange() async {
    final ahora = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(ahora.year - 2),
      lastDate: ahora,
      // Pantalla 15: "Por defecto puede mostrar el último mes".
      initialDateRange:
          _range ??
          DateTimeRange(
            start: ahora.subtract(const Duration(days: 30)),
            end: ahora,
          ),
    );
    if (range == null) return;
    _range = range;
    await _loadMore(reset: true);
  }

  bool get _canManage {
    final role = context.read<SessionController>().user?.rol;
    return role == 'Ropera' || role == 'Encargado de Ropería y Lavandería';
  }

  Future<void> _advance(Map<String, dynamic> lot) async {
    final token = _token;
    if (token == null) return;
    await _api.patch('/lotes/${lot['id']}/etapa', token, {
      'etapa': 'en_lavado',
    });
    if (mounted) await _loadMore(reset: true);
  }

  Future<void> _deliver(Map<String, dynamic> lot) async {
    final item = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar entrega limpia'),
        content: TextField(
          controller: item,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'N° de ítem de quien recibe (opcional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    final token = _token;
    if (confirmed == true && token != null) {
      final response =
          await _api.post('/lotes/${lot['id']}/entrega-limpia', token, {
                'numero_item_recibe': item.text.trim().isEmpty
                    ? null
                    : item.text.trim(),
              })
              as Map<String, dynamic>;
      if (mounted) {
        // El servidor avisa si parte del lote se dio de baja mientras estaba
        // en lavandería y por tanto no volvió al área.
        final aviso = response['aviso'] as String?;
        if (aviso != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(aviso)));
        }
        await _loadMore(reset: true);
      }
    }
    item.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Historial de lotes')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              if (_workers.isNotEmpty)
                SegmentedButton<_FilterKind>(
                  segments: const [
                    ButtonSegment(value: _FilterKind.area, label: Text('Área')),
                    ButtonSegment(
                      value: _FilterKind.worker,
                      label: Text('Trabajador'),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _kind = selection.first;
                      _areaId = null;
                      _workerId = null;
                    });
                    _loadMore(reset: true);
                  },
                ),
              if (_kind == _FilterKind.area)
                DropdownButtonFormField<int?>(
                  initialValue: _areaId,
                  decoration: const InputDecoration(labelText: 'Área'),
                  items: [
                    const DropdownMenuItem(child: Text('Todas las áreas')),
                    ..._areas.cast<Map<String, dynamic>>().map(
                      (area) => DropdownMenuItem(
                        value: area['id'] as int,
                        child: Text(area['nombre'] as String),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    _areaId = value;
                    _loadMore(reset: true);
                  },
                )
              else
                DropdownButtonFormField<int?>(
                  initialValue: _workerId,
                  decoration: const InputDecoration(labelText: 'Trabajador'),
                  items: [
                    const DropdownMenuItem(
                      child: Text('Todos los trabajadores'),
                    ),
                    ..._workers.cast<Map<String, dynamic>>().map(
                      (worker) => DropdownMenuItem(
                        value: worker['id'] as int,
                        child: Text(worker['nombre'] as String),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    _workerId = value;
                    _loadMore(reset: true);
                  },
                ),
              DropdownButtonFormField<String?>(
                initialValue: _stage,
                decoration: const InputDecoration(labelText: 'Etapa'),
                items: _stages.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  _stage = value;
                  _loadMore(reset: true);
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _range == null
                          ? 'Todas las fechas'
                          : '${_fecha(_range!.start)} a ${_fecha(_range!.end)}',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickRange,
                    icon: const Icon(Icons.date_range),
                    label: const Text('Rango'),
                  ),
                  if (_range != null)
                    IconButton(
                      tooltip: 'Quitar el rango de fechas',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _range = null;
                        _loadMore(reset: true);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(child: _buildList()),
      ],
    ),
  );

  Widget _buildList() {
    if (_lots.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return const Center(child: Text('Aún no hay lotes registrados.'));
    }
    return RefreshIndicator(
      onRefresh: () => _loadMore(reset: true),
      child: ListView.builder(
        itemCount: _lots.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _lots.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _loading
                    ? const CircularProgressIndicator()
                    : OutlinedButton(
                        onPressed: _loadMore,
                        child: const Text('Cargar lotes anteriores'),
                      ),
              ),
            );
          }
          final lot = _lots[index] as Map<String, dynamic>;
          final area = lot['area'] as Map<String, dynamic>?;
          final details = (lot['detalles'] as List<dynamic>? ?? [])
              .map((item) {
                final detail = item as Map<String, dynamic>;
                final cloth = detail['tipo_prenda'] as Map<String, dynamic>?;
                return '${cloth?['nombre'] ?? 'Prenda'}: ${detail['cantidad']}';
              })
              .join(', ');
          final stage = lot['etapa'] as String;
          return Card(
            child: ListTile(
              title: Text('Lote #${lot['id']} — ${area?['nombre'] ?? 'Área'}'),
              subtitle: Text(
                '$details\nEtapa: ${lot['etapa']} · ${lot['peso_kg']} kg',
              ),
              isThreeLine: true,
              trailing: !_canManage || stage == 'limpio_entregado'
                  ? null
                  : PopupMenuButton<String>(
                      onSelected: (action) async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          if (action == 'lavado') await _advance(lot);
                          if (action == 'entrega') await _deliver(lot);
                        } catch (error) {
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('$error')),
                            );
                          }
                        }
                      },
                      itemBuilder: (_) => [
                        if (stage == 'sucio_recibido')
                          const PopupMenuItem(
                            value: 'lavado',
                            child: Text('Pasar a lavado'),
                          ),
                        if (stage == 'en_lavado')
                          const PopupMenuItem(
                            value: 'entrega',
                            child: Text('Entregar limpio'),
                          ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}

/// Pantalla 15: el historial se filtra por trabajador o por área, no por ambos.
enum _FilterKind { area, worker }

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/sync/sync_controller.dart';
import '../application/local_ocr_service.dart';

class OcrReviewScreen extends StatefulWidget {
  const OcrReviewScreen({super.key, required this.result});
  final OcrResult result;

  @override
  State<OcrReviewScreen> createState() => _OcrReviewScreenState();
}

class _OcrReviewScreenState extends State<OcrReviewScreen> {
  final _item = TextEditingController();
  final _name = TextEditingController();
  final _weight = TextEditingController();
  final _amounts = <int, TextEditingController>{};
  late Future<List<List<dynamic>>> _catalogue;
  int? _areaId;
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _item.text = widget.result.itemNumber ?? '';
    final api = context.read<SyncController>();
    _catalogue = Future.wait([
      api
          .cachedGet('/catalogo/areas', cacheKey: 'catalogo_areas')
          .then((v) => v as List<dynamic>),
      api
          .cachedGet('/catalogo/prendas', cacheKey: 'catalogo_prendas')
          .then((v) => v as List<dynamic>),
    ]);
  }

  @override
  void dispose() {
    _item.dispose();
    _name.dispose();
    _weight.dispose();
    for (final controller in _amounts.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _prepare(List<dynamic> areas, List<dynamic> clothes) {
    const matcher = OcrCatalogMatcher();
    _areaId ??= matcher.areaId(widget.result.rawText, areas);
    for (final entry in matcher.clothes(widget.result.lines, clothes).entries) {
      _amounts.putIfAbsent(
        entry.key,
        () => TextEditingController(text: '${entry.value}'),
      );
    }
  }

  Future<void> _save() async {
    final sync = context.read<SyncController>();
    final details = _amounts.entries
        .map(
          (entry) => {
            'tipo_prenda_id': entry.key,
            'cantidad': int.tryParse(entry.value.text) ?? 0,
          },
        )
        .where((item) => (item['cantidad'] as int) > 0)
        .toList();
    if (_areaId == null ||
        details.isEmpty ||
        double.tryParse(_weight.text.replaceAll(',', '.')) == null) {
      setState(
        () => _message = 'Seleccione área, ingrese peso y al menos una prenda.',
      );
      return;
    }
    final okay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Guardar cambios?'),
        content: const Text('Revise las cantidades antes de crear el lote.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (okay != true) return;
    setState(() => _saving = true);
    try {
      final submission = await sync.submit(
        entityType: 'lote',
        path: '/lotes',
        payload: {
          'area_id': _areaId,
          'numero_item_entrega': _item.text.isEmpty ? null : _item.text,
          'nombre_quien_trae': _name.text.isEmpty ? null : _name.text,
          'peso_kg': double.parse(_weight.text.replaceAll(',', '.')),
          'detalles': details,
          'origen_registro': 'ocr_local',
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              submission.queued
                  ? 'Lote OCR guardado sin conexión; se sincronizará automáticamente.'
                  : 'Lote OCR guardado.',
            ),
          ),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (error) {
      if (mounted) setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Revisar datos OCR')),
    body: FutureBuilder<List<List<dynamic>>>(
      future: _catalogue,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final areas = snapshot.data![0];
        final clothes = snapshot.data![1];
        _prepare(areas, clothes);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _item,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: const InputDecoration(
                labelText: 'N° de ítem (opcional)',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _areaId,
              decoration: const InputDecoration(labelText: 'Servicio / Área'),
              items: areas
                  .cast<Map<String, dynamic>>()
                  .where((a) => a['activo'] == true)
                  .map(
                    (a) => DropdownMenuItem(
                      value: a['id'] as int,
                      child: Text(a['nombre'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _areaId = value),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Nombre de quien trae (opcional)',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Peso total (kg)'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Prendas detectadas',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            for (final entry in _amounts.entries)
              _AmountRow(
                name:
                    clothes.cast<Map<String, dynamic>>().firstWhere(
                          (c) => c['id'] == entry.key,
                        )['nombre']
                        as String,
                controller: entry.value,
                onChanged: () => setState(() {}),
              ),
            if (_amounts.isEmpty)
              const Text(
                'No hubo coincidencias. Use Registro manual como respaldo.',
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Guardando…' : 'Guardar lote'),
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_message!),
              ),
          ],
        );
      },
    ),
  );
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.name,
    required this.controller,
    required this.onChanged,
  });
  final String name;
  final TextEditingController controller;
  final VoidCallback onChanged;
  int get value => int.tryParse(controller.text) ?? 0;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 10),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(name)),
          IconButton(
            onPressed: value > 0
                ? () {
                    controller.text = '${value - 1}';
                    onChanged();
                  }
                : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 52,
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
            ),
          ),
          IconButton(
            onPressed: value < 999
                ? () {
                    controller.text = '${value + 1}';
                    onChanged();
                  }
                : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    ),
  );
}

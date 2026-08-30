import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/network/authenticated_api_client.dart';
import '../../auth/application/session_controller.dart';

class BajaFormScreen extends StatefulWidget {
  const BajaFormScreen({super.key});

  @override
  State<BajaFormScreen> createState() => _BajaFormScreenState();
}

class _BajaFormScreenState extends State<BajaFormScreen> {
  static const _reasons = [
    'Rota / rasgada',
    'Manchada sin arreglo',
    'Desgastada por uso',
    'Costura descosida sin reparación posible',
    'Perdida',
    'Quemada',
    'Otro',
  ];

  final _amount = TextEditingController();
  final _description = TextEditingController();
  late Future<List<List<dynamic>>> _catalogue;
  int? _areaId;
  int? _clothId;
  String? _reason;
  File? _photo;
  bool _saving = false;
  String? _message;

  String get _token => context.read<SessionController>().token!;

  @override
  void initState() {
    super.initState();
    final api = AuthenticatedApiClient();
    _catalogue = Future.wait([
      api
          .get('/catalogo/areas', _token)
          .then((value) => value as List<dynamic>),
      api
          .get('/catalogo/prendas', _token)
          .then((value) => value as List<dynamic>),
    ]);
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _selectPhoto(ImageSource source) async {
    final photo = await ImagePicker().pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1600,
    );
    if (photo != null && mounted) setState(() => _photo = File(photo.path));
  }

  Future<void> _save() async {
    final amount = int.tryParse(_amount.text);
    if (_areaId == null ||
        _clothId == null ||
        _reason == null ||
        amount == null ||
        amount < 1) {
      setState(() => _message = 'Complete área, prenda, cantidad y motivo.');
      return;
    }
    if (_reason == 'Otro' && _description.text.trim().isEmpty) {
      setState(() => _message = 'Describa el motivo cuando selecciona “Otro”.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar baja permanente'),
        content: Text(
          'Se descontarán $amount unidades del stock. Esta acción no se puede editar.',
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
    if (confirmed != true) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final api = AuthenticatedApiClient();
      final photoUrl = _photo == null
          ? null
          : await api.uploadPhoto(_token, _photo!, category: 'bajas');
      await api.post('/bajas', _token, {
        'area_id': _areaId,
        'tipo_prenda_id': _clothId,
        'cantidad': amount,
        'motivo': _reason,
        'descripcion': _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        'foto_evidencia_url': photoUrl,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Baja registrada y stock actualizado.')),
        );
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Dar de baja prenda')),
    body: FutureBuilder<List<List<dynamic>>>(
      future: _catalogue,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final areas = snapshot.data![0].cast<Map<String, dynamic>>();
        final clothes = snapshot.data![1].cast<Map<String, dynamic>>();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Área'),
              items: areas
                  .where((item) => item['activo'] == true)
                  .map(
                    (item) => DropdownMenuItem(
                      value: item['id'] as int,
                      child: Text(item['nombre'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _areaId = value),
            ),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Prenda'),
              items: clothes
                  .where((item) => item['activo'] == true)
                  .map(
                    (item) => DropdownMenuItem(
                      value: item['id'] as int,
                      child: Text(item['nombre'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _clothId = value),
            ),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: const InputDecoration(labelText: 'Cantidad'),
            ),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Motivo'),
              items: _reasons
                  .map(
                    (reason) =>
                        DropdownMenuItem(value: reason, child: Text(reason)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _reason = value),
            ),
            if (_reason == 'Otro')
              TextField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción obligatoria',
                ),
              ),
            const SizedBox(height: 12),
            const Text('Foto de evidencia opcional'),
            if (_photo != null)
              Image.file(_photo!, height: 160, fit: BoxFit.cover),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _saving
                      ? null
                      : () => _selectPhoto(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Cámara'),
                ),
                TextButton.icon(
                  onPressed: _saving
                      ? null
                      : () => _selectPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galería'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Guardando…' : 'Confirmar baja'),
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_message!),
              ),
          ],
        );
      },
    ),
  );
}

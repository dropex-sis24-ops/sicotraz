import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/network/authenticated_api_client.dart';
import '../../auth/application/session_controller.dart';

class AlertFormScreen extends StatefulWidget {
  const AlertFormScreen({super.key, this.initialAreaId});
  final int? initialAreaId;

  @override
  State<AlertFormScreen> createState() => _AlertFormScreenState();
}

class _AlertFormScreenState extends State<AlertFormScreen> {
  final _description = TextEditingController();
  int? _areaId;
  int? _prendaId;
  late Future<List<dynamic>> _areas;
  late Future<List<dynamic>> _prendas;
  String? _message;
  File? _photo;
  bool _saving = false;
  String get _token => context.read<SessionController>().token!;

  @override
  void initState() {
    super.initState();
    _areaId =
        widget.initialAreaId ?? context.read<SessionController>().user?.areaId;
    final api = AuthenticatedApiClient();
    _areas = api
        .get('/catalogo/areas', _token)
        .then((value) => value as List<dynamic>);
    _prendas = api
        .get('/catalogo/prendas', _token)
        .then((value) => value as List<dynamic>);
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_prendaId == null || _description.text.trim().isEmpty) {
      setState(() => _message = 'Seleccione la prenda y describa qué ocurrió.');
      return;
    }
    try {
      setState(() => _saving = true);
      final api = AuthenticatedApiClient();
      final photoUrl = _photo == null
          ? null
          : await api.uploadPhoto(_token, _photo!);
      await api.post('/alertas', _token, {
        'area_id': _areaId,
        'tipo_prenda_id': _prendaId,
        'descripcion': _description.text.trim(),
        'foto_evidencia_url': photoUrl,
      });
      if (mounted) {
        setState(() {
          _message = 'Alerta registrada correctamente.';
          _description.clear();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = '$error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final selected = await ImagePicker().pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1600,
    );
    if (selected != null && mounted) {
      setState(() => _photo = File(selected.path));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Registrar alerta')),
    body: FutureBuilder<List<dynamic>>(
      future: _areas,
      builder: (_, areaSnapshot) {
        if (!areaSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return FutureBuilder<List<dynamic>>(
          future: _prendas,
          builder: (_, prendaSnapshot) {
            if (!prendaSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final isManual =
                context.read<SessionController>().user?.rol ==
                'Personal manual';
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (isManual)
                  Text(
                    'Área: ${context.read<SessionController>().user?.areaNombre ?? 'asignada'}',
                  )
                else
                  DropdownButtonFormField<int>(
                    initialValue: _areaId,
                    decoration: const InputDecoration(labelText: 'Área'),
                    items: areaSnapshot.data!
                        .cast<Map<String, dynamic>>()
                        .where((x) => x['activo'] == true)
                        .map(
                          (x) => DropdownMenuItem(
                            value: x['id'] as int,
                            child: Text(x['nombre'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _areaId = value),
                  ),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Prenda'),
                  items: prendaSnapshot.data!
                      .cast<Map<String, dynamic>>()
                      .where((x) => x['activo'] == true)
                      .map(
                        (x) => DropdownMenuItem(
                          value: x['id'] as int,
                          child: Text(x['nombre'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _prendaId = value),
                ),
                TextField(
                  controller: _description,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Descripción de lo ocurrido',
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Foto de evidencia opcional'),
                if (_photo != null) ...[
                  const SizedBox(height: 8),
                  Image.file(_photo!, height: 160, fit: BoxFit.cover),
                ],
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _pickPhoto(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Cámara'),
                    ),
                    TextButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _pickPhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galería'),
                    ),
                    if (_photo != null)
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => setState(() => _photo = null),
                        child: const Text('Quitar'),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Guardando…' : 'Registrar alerta'),
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_message!),
                  ),
              ],
            );
          },
        );
      },
    ),
  );
}

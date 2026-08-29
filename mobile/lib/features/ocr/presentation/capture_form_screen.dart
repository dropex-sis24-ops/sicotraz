import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../application/local_ocr_service.dart';
import 'ocr_review_screen.dart';

class CaptureFormScreen extends StatefulWidget {
  const CaptureFormScreen({super.key});

  @override
  State<CaptureFormScreen> createState() => _CaptureFormScreenState();
}

class _CaptureFormScreenState extends State<CaptureFormScreen> {
  bool _processing = false;
  String? _error;
  OcrResult? _result;

  Future<void> _capture(ImageSource source) async {
    final image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2200,
    );
    if (image == null) return;
    setState(() {
      _processing = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await LocalOcrService().read(File(image.path));
      if (mounted) {
        setState(() => _result = result);
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo procesar la foto. Intente otra imagen más nítida.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Capturar formulario')),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tome una foto clara de la lista física o selecciónela desde la galería.',
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _processing ? null : () => _capture(ImageSource.camera),
            icon: const Icon(Icons.photo_camera),
            label: const Text('Tomar foto'),
          ),
          OutlinedButton.icon(
            onPressed: _processing ? null : () => _capture(ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('Subir desde galería'),
          ),
          if (_processing)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_result != null)
            Expanded(
              child: _Preview(
                result: _result!,
                onReview: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OcrReviewScreen(result: _result!),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _Preview extends StatelessWidget {
  const _Preview({required this.result, required this.onReview});
  final OcrResult result;
  final VoidCallback onReview;
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      const SizedBox(height: 12),
      const Text(
        'Lectura detectada',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      if (result.itemNumber != null) Text('Ítem: ${result.itemNumber}'),
      for (final line in result.lines)
        ListTile(title: Text(line.label), trailing: Text('${line.quantity}')),
      FilledButton(
        onPressed: onReview,
        child: const Text('Revisar y corregir'),
      ),
      const Divider(),
      const Text('Texto OCR (para diagnóstico):'),
      Text(result.rawText),
    ],
  );
}

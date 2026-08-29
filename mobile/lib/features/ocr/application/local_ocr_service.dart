import 'dart:io';

import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';

class OcrLine {
  const OcrLine({required this.label, required this.quantity});
  final String label;
  final int quantity;
}

class OcrResult {
  const OcrResult({
    required this.rawText,
    required this.lines,
    this.itemNumber,
  });
  final String rawText;
  final List<OcrLine> lines;
  final String? itemNumber;
}

/// RF05–RF09: lectura local; nunca envía la imagen a un servidor.
class LocalOcrService {
  Future<OcrResult> read(File image) async {
    final text = await FlutterTesseractOcr.extractText(
      image.path,
      language: 'spa',
      args: const {'psm': '4', 'preserve_interword_spaces': '1'},
    );
    final lines = <OcrLine>[];
    final match = RegExp(
      r'^\s*([^0-9]{2,}?)\s*[:; -]+\s*(\d{1,3})\s*$',
      multiLine: true,
    );
    for (final entry in match.allMatches(text)) {
      lines.add(
        OcrLine(
          label: entry.group(1)!.trim(),
          quantity: int.parse(entry.group(2)!),
        ),
      );
    }
    final item = RegExp(
      r'(?:c[oó]digo|item|ítem)\s*[:#-]?\s*(\d{1,10})',
      caseSensitive: false,
    ).firstMatch(text)?.group(1);
    if (lines.isEmpty) {
      throw const FormatException('No se pudieron leer prendas y cantidades.');
    }
    return OcrResult(rawText: text, lines: lines, itemNumber: item);
  }
}

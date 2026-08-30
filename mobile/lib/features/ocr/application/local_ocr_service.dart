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

class OcrText {
  static String normalize(String value) {
    var normalized = value.toLowerCase();
    const accents = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    for (final entry in accents.entries) {
      normalized = normalized.replaceAll(entry.key, entry.value);
    }
    return normalized.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}

class OcrParser {
  const OcrParser();

  OcrResult parse(String text) {
    final lines = <OcrLine>[];
    final rowPattern = RegExp(r'^(.{2,}?)\s*[:;= -]+\s*(\d{1,3})\s*$');
    for (final rawLine in text.split(RegExp(r'\r?\n'))) {
      final cleaned = rawLine.replaceAll('|', ' ').trim();
      final match = rowPattern.firstMatch(cleaned);
      if (match == null) continue;
      final label = match.group(1)!.trim();
      final quantity = int.parse(match.group(2)!);
      if (quantity <= 999 && !OcrText.normalize(label).contains('cantidad')) {
        lines.add(OcrLine(label: label, quantity: quantity));
      }
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

class OcrCatalogMatcher {
  const OcrCatalogMatcher();

  int? areaId(String rawText, List<dynamic> areas) {
    final normalizedLines = rawText
        .split(RegExp(r'\r?\n'))
        .map(OcrText.normalize);
    for (final area in areas.cast<Map<String, dynamic>>()) {
      final candidates = <String>[
        area['nombre'] as String,
        ...((area['aliases'] as List<dynamic>? ?? []).map(
          (alias) =>
              (alias as Map<String, dynamic>)['alias_normalizado'] as String,
        )),
      ];
      for (final candidateRaw in candidates) {
        final candidate = OcrText.normalize(candidateRaw);
        final found = normalizedLines.any(
          (line) => candidate.length <= 3
              ? line == candidate || line.endsWith(candidate)
              : line.contains(candidate),
        );
        if (found) return area['id'] as int;
      }
    }
    return null;
  }

  Map<int, int> clothes(List<OcrLine> lines, List<dynamic> catalogue) {
    final result = <int, int>{};
    for (final detected in lines) {
      final value = OcrText.normalize(detected.label);
      final match = catalogue.cast<Map<String, dynamic>>().where((item) {
        final fullName = item['nombre'] as String;
        final name = OcrText.normalize(fullName);
        final base = OcrText.normalize(fullName.split('(').first);
        return value == name ||
            value == base ||
            (value.length >= 3 &&
                (value.contains(base) || base.contains(value)));
      }).firstOrNull;
      if (match != null) result[match['id'] as int] = detected.quantity;
    }
    return result;
  }
}

/// RF05–RF09: lectura local; nunca envía la imagen a un servidor.
class LocalOcrService {
  Future<OcrResult> read(File image) async {
    final text = await FlutterTesseractOcr.extractText(
      image.path,
      language: 'spa',
      args: const {'psm': '4', 'preserve_interword_spaces': '1'},
    );
    return const OcrParser().parse(text);
  }
}

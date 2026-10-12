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
    this.templateName,
    this.formDate,
  });
  final String rawText;
  final List<OcrLine> lines;
  final String? itemNumber;
  final String? templateName;
  final String? formDate;
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
    // El nombre se toma completo hasta la cantidad final: con el guion y el
    // espacio como separadores, "Cubre-camas 5" se leía como "Cubre".
    final rowPattern = RegExp(
      r'^(.*?[A-Za-zÁÉÍÓÚÜÑáéíóúüñ].*?)[\s:;=.-]+(\d{1,3})\s*$',
    );
    for (final rawLine in text.split(RegExp(r'\r?\n'))) {
      final cleaned = rawLine.replaceAll('|', ' ').trim();
      final match = rowPattern.firstMatch(cleaned);
      if (match == null) continue;
      final label = match
          .group(1)!
          .trim()
          .replaceAll(RegExp(r'[\s:;=.-]+$'), '');
      final quantity = int.parse(match.group(2)!);
      if (quantity <= 999 && !OcrText.normalize(label).contains('cantidad')) {
        lines.add(OcrLine(label: label, quantity: quantity));
      }
    }
    final item = RegExp(
      r'(?:c[oó]digo|item|ítem)\s*[:#-]?\s*(\d{1,10})',
      caseSensitive: false,
    ).firstMatch(text)?.group(1);
    final date = RegExp(
      r'\b(0?[1-9]|[12]\d|3[01])[\/-](0?[1-9]|1[0-2])[\/-](20\d{2})\b',
    ).firstMatch(text)?.group(0);
    if (lines.isEmpty) {
      throw const FormatException('No se pudieron leer prendas y cantidades.');
    }
    return OcrResult(
      rawText: text,
      lines: lines,
      itemNumber: item,
      templateName: detectTemplate(text),
      formDate: date,
    );
  }

  String? detectTemplate(String text) {
    final normalized = OcrText.normalize(text);
    const operatingRoomMarkers = [
      'quirofano',
      'campogrande',
      'fundamayo',
      'campopaciente',
      'pechera',
    ];
    if (operatingRoomMarkers.any(normalized.contains)) return 'Quirófano';
    const roomMarkers = [
      'salas',
      'cubrecamas',
      'sabanassuperiores',
      'colchonetas',
      'secador',
    ];
    if (roomMarkers.any(normalized.contains)) return 'Salas';
    return null;
  }
}

class OcrCatalogMatcher {
  const OcrCatalogMatcher();

  int? areaId(String rawText, List<dynamic> areas) {
    // Cada línea se compara entera y también por segmentos ("Servicio: C.V."
    // → "serviciocv" y "cv"). Un alias corto debe coincidir con un segmento
    // completo: buscarlo como sufijo de cualquier palabra daba falsos
    // positivos.
    final lines = <String>[];
    final segments = <String>[];
    for (final rawLine in rawText.split(RegExp(r'\r?\n'))) {
      final line = OcrText.normalize(rawLine);
      if (line.isNotEmpty) lines.add(line);
      for (final rawSegment in rawLine.split(RegExp(r'[:;=|,\t]|\s-\s'))) {
        final segment = OcrText.normalize(rawSegment);
        if (segment.isNotEmpty) segments.add(segment);
      }
    }
    final matches = <int, int>{};

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
        if (candidate.isEmpty) continue;
        final found =
            segments.contains(candidate) ||
            (candidate.length > 3 &&
                lines.any((line) => line.contains(candidate)));
        if (found) {
          // Se conserva la coincidencia más específica de cada área.
          final actual = matches[area['id'] as int] ?? 0;
          if (candidate.length > actual) {
            matches[area['id'] as int] = candidate.length;
          }
        }
      }
    }
    if (matches.isEmpty) return null;

    // Con varias áreas candidatas gana la coincidencia más larga; si dos
    // empatan ("Sala 1" y "Sala 10") no se elige ninguna y lo confirma la
    // persona, en lugar de asignar el lote a un área equivocada.
    final ordenadas = matches.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (ordenadas.length > 1 && ordenadas[0].value == ordenadas[1].value) {
      return null;
    }
    return ordenadas.first.key;
  }

  /// Empareja las líneas leídas con el catálogo. Devuelve también las líneas
  /// que no se pudieron resolver con seguridad para que las confirme la
  /// persona: antes se asignaban a la primera prenda parecida en silencio.
  OcrMatchResult clothesWithReview(
    List<OcrLine> lines,
    List<dynamic> catalogue,
  ) {
    final result = <int, int>{};
    final unresolved = <OcrAmbiguity>[];
    final items = catalogue.cast<Map<String, dynamic>>();

    for (final detected in lines) {
      final value = OcrText.normalize(detected.label);
      final exact = items.where((item) {
        final fullName = item['nombre'] as String;
        return value == OcrText.normalize(fullName) ||
            value == OcrText.normalize(fullName.split('(').first);
      }).toList();

      // Solo si no hay coincidencia exacta se admite la parcial, y únicamente
      // cuando apunta a una sola prenda del catálogo.
      final candidates = exact.isNotEmpty
          ? exact
          : items.where((item) {
              final base = OcrText.normalize(
                (item['nombre'] as String).split('(').first,
              );
              return value.length >= 4 &&
                  base.length >= 4 &&
                  (value.contains(base) || base.contains(value));
            }).toList();

      if (candidates.length != 1) {
        unresolved.add(
          OcrAmbiguity(
            label: detected.label,
            quantity: detected.quantity,
            candidates: candidates
                .map((item) => item['id'] as int)
                .toList(growable: false),
          ),
        );
        continue;
      }
      final id = candidates.single['id'] as int;
      // Dos líneas de la misma prenda se suman en lugar de sobrescribirse.
      result[id] = (result[id] ?? 0) + detected.quantity;
    }

    return OcrMatchResult(quantities: result, unresolved: unresolved);
  }

  Map<int, int> clothes(List<OcrLine> lines, List<dynamic> catalogue) =>
      clothesWithReview(lines, catalogue).quantities;
}

/// Línea leída que no se pudo asignar a una sola prenda del catálogo.
class OcrAmbiguity {
  const OcrAmbiguity({
    required this.label,
    required this.quantity,
    required this.candidates,
  });

  final String label;
  final int quantity;
  final List<int> candidates;

  bool get isUnknown => candidates.isEmpty;
}

class OcrMatchResult {
  const OcrMatchResult({required this.quantities, required this.unresolved});

  final Map<int, int> quantities;
  final List<OcrAmbiguity> unresolved;
}

/// RF05–RF09: lectura local; nunca envía la imagen a un servidor.
class LocalOcrService {
  Future<OcrResult> read(File image) async {
    final String text;
    try {
      text = await FlutterTesseractOcr.extractText(
        image.path,
        language: 'spa',
        args: const {'psm': '4', 'preserve_interword_spaces': '1'},
      );
    } catch (_) {
      // El error de Tesseract no dice nada útil a quien usa la app.
      throw const FormatException(
        'No fue posible leer la foto. Repita la captura con mejor luz y '
        'el formulario completo dentro del encuadre.',
      );
    }
    return const OcrParser().parse(text);
  }
}

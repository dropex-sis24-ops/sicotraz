class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.errors});

  final String message;
  final int? statusCode;

  /// Errores por campo que devuelve Laravel en una respuesta 422.
  final Map<String, List<String>>? errors;

  /// La sesión dejó de ser válida: el token caducó o fue revocado al
  /// desactivar la cuenta o restablecer la contraseña.
  bool get isUnauthenticated => statusCode == 401;

  /// Construye el mensaje a partir del cuerpo de la respuesta, prefiriendo el
  /// primer error de campo: el `message` de un 422 es genérico y no dice nada
  /// útil a quien está rellenando el formulario.
  factory ApiException.fromBody(
    Map<String, dynamic>? body,
    int statusCode, {
    required String fallback,
  }) {
    final rawErrors = body?['errors'];
    Map<String, List<String>>? errors;
    if (rawErrors is Map) {
      errors = rawErrors.map(
        (key, value) => MapEntry(
          '$key',
          (value as List<dynamic>).map((item) => '$item').toList(),
        ),
      );
    }
    final firstFieldError = errors?.values
        .firstWhere((messages) => messages.isNotEmpty, orElse: () => const [])
        .firstOrNull;

    return ApiException(
      firstFieldError ?? body?['message'] as String? ?? fallback,
      statusCode: statusCode,
      errors: errors,
    );
  }

  @override
  String toString() => message;
}

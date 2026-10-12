import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

class AuthenticatedApiClient {
  AuthenticatedApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? _shared,
      _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'https://sicotraz-api.test/api',
          );

  /// Cliente compartido: las pantallas instancian este servicio en cada
  /// llamada y un `http.Client` por petición deja conexiones sin cerrar.
  static final http.Client _shared = http.Client();

  /// En la red del hospital una petición sin límite deja la pantalla colgada
  /// indefinidamente en lugar de pasar al modo sin conexión.
  static const timeout = Duration(seconds: 20);
  static const uploadTimeout = Duration(seconds: 60);

  /// Se invoca cuando el servidor responde 401: el token caducó o fue
  /// revocado, así que la sesión debe cerrarse y volver al login.
  static void Function()? onUnauthenticated;

  final http.Client _client;
  final String _baseUrl;

  Future<dynamic> get(String path, String token) =>
      _request('GET', path, token);
  Future<dynamic> post(
    String path,
    String token, [
    Map<String, dynamic>? body,
  ]) => _request('POST', path, token, body);
  Future<dynamic> patch(
    String path,
    String token, [
    Map<String, dynamic>? body,
  ]) => _request('PATCH', path, token, body);
  Future<dynamic> put(
    String path,
    String token, [
    Map<String, dynamic>? body,
  ]) => _request('PUT', path, token, body);
  Future<dynamic> delete(String path, String token) =>
      _request('DELETE', path, token);

  Future<String> uploadPhoto(
    String token,
    File photo, {
    String category = 'alertas',
  }) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$_baseUrl/archivos'))
          ..headers['Accept'] = 'application/json'
          ..headers['Authorization'] = 'Bearer $token'
          ..fields['categoria'] = category
          ..files.add(await http.MultipartFile.fromPath('foto', photo.path));
    final response = await http.Response.fromStream(
      await request.send().timeout(uploadTimeout),
    );
    final data = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _failure(
        data,
        response.statusCode,
        'No fue posible subir la foto.',
      );
    }
    return (data as Map<String, dynamic>)['url'] as String;
  }

  Future<Uint8List> download(String path, String token) async {
    final response = await _client
        .get(
          Uri.parse('$_baseUrl$path'),
          headers: {
            'Accept': 'application/pdf',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _failure(
        null,
        response.statusCode,
        'No fue posible generar el PDF.',
      );
    }
    return response.bodyBytes;
  }

  Future<dynamic> _request(
    String method,
    String path,
    String token, [
    Map<String, dynamic>? body,
  ]) async {
    final request = http.Request(method, Uri.parse('$_baseUrl$path'))
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await _client.send(request).timeout(timeout),
    );
    final data = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _failure(
        data,
        response.statusCode,
        'No fue posible completar la operación.',
      );
    }
    return data;
  }

  ApiException _failure(dynamic data, int statusCode, String fallback) {
    final failure = ApiException.fromBody(
      data is Map<String, dynamic> ? data : null,
      statusCode,
      fallback: fallback,
    );
    // Una sesión revocada dejaba la app en un estado en que todo fallaba sin
    // ninguna vía de vuelta al login.
    if (failure.isUnauthenticated) onUnauthenticated?.call();
    return failure;
  }
}

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

class AuthenticatedApiClient {
  AuthenticatedApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'https://sicotraz-api.test/api',
          );

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
      await _client.send(request),
    );
    final data = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        (data as Map<String, dynamic>?)?['message'] as String? ??
            'No fue posible completar la operación.',
        statusCode: response.statusCode,
      );
    }
    return data;
  }
}

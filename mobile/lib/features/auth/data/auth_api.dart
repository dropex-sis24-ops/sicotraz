import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_exception.dart';
import '../domain/session_user.dart';

class LoginResult {
  const LoginResult({required this.token, required this.user});

  final String token;
  final SessionUser user;
}

class AuthApi {
  AuthApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'https://sicotraz-api.test/api',
          );

  final http.Client _client;
  final String _baseUrl;

  Future<LoginResult> login({
    required String numeroItem,
    required String password,
  }) async {
    final response = await _post('/login', {
      'numero_item': numeroItem,
      'password': password,
    });
    final body = _decode(response);

    return LoginResult(
      token: body['token'] as String,
      user: SessionUser.fromJson(body['usuario'] as Map<String, dynamic>),
    );
  }

  Future<SessionUser> cambiarPassword({
    required String token,
    required String passwordNueva,
    required String passwordNuevaConfirmation,
  }) async {
    final response = await _post('/cambiar-password', {
      'password_nueva': passwordNueva,
      'password_nueva_confirmation': passwordNuevaConfirmation,
    }, token: token);

    final body = _decode(response);
    return SessionUser.fromJson(body['usuario'] as Map<String, dynamic>);
  }

  Future<void> logout(String token) async {
    final response = await _post('/logout', const {}, token: token);
    if (response.statusCode != 204) _decode(response);
  }

  Future<http.Response> _post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) => _client.post(
    Uri.parse('$_baseUrl$path'),
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
    body: jsonEncode(body),
  );

  Map<String, dynamic> _decode(http.Response response) {
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        body['message'] as String? ?? 'No fue posible completar la operación.',
        statusCode: response.statusCode,
      );
    }

    return body;
  }
}

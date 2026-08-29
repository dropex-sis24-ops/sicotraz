import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_exception.dart';
import '../data/auth_api.dart';
import '../domain/session_user.dart';

enum SessionStatus {
  loading,
  unauthenticated,
  passwordChangeRequired,
  authenticated,
}

class SessionController extends ChangeNotifier {
  SessionController({AuthApi? api, FlutterSecureStorage? storage})
    : _api = api ?? AuthApi(),
      _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'sicotraz_auth_token';
  static const _userKey = 'sicotraz_session_user';

  final AuthApi _api;
  final FlutterSecureStorage _storage;

  SessionStatus status = SessionStatus.unauthenticated;
  SessionUser? user;
  String? _token;
  String? errorMessage;
  String? get token => _token;

  Future<void> restore() async {
    status = SessionStatus.loading;
    notifyListeners();

    try {
      final token = await _storage.read(key: _tokenKey);
      final rawUser = await _storage.read(key: _userKey);

      if (token != null && rawUser != null) {
        _token = token;
        user = SessionUser.fromJson(
          jsonDecode(rawUser) as Map<String, dynamic>,
        );
        status = user!.debeCambiarPassword
            ? SessionStatus.passwordChangeRequired
            : SessionStatus.authenticated;
      } else {
        status = SessionStatus.unauthenticated;
      }
    } catch (_) {
      await _clearStoredSession();
      status = SessionStatus.unauthenticated;
    }

    notifyListeners();
  }

  Future<void> login(String numeroItem, String password) async {
    errorMessage = null;
    status = SessionStatus.loading;
    notifyListeners();

    try {
      final result = await _api.login(
        numeroItem: numeroItem,
        password: password,
      );
      _token = result.token;
      user = result.user;
      await _saveSession();
      status = user!.debeCambiarPassword
          ? SessionStatus.passwordChangeRequired
          : SessionStatus.authenticated;
    } on ApiException catch (error) {
      errorMessage = error.message;
      status = SessionStatus.unauthenticated;
    } catch (_) {
      errorMessage = 'No fue posible conectar con el servidor.';
      status = SessionStatus.unauthenticated;
    }

    notifyListeners();
  }

  Future<void> changePassword(String passwordNueva, String confirmation) async {
    if (_token == null) {
      await logout();
      return;
    }

    errorMessage = null;
    status = SessionStatus.loading;
    notifyListeners();

    try {
      user = await _api.cambiarPassword(
        token: _token!,
        passwordNueva: passwordNueva,
        passwordNuevaConfirmation: confirmation,
      );
      await _saveSession();
      status = SessionStatus.authenticated;
    } on ApiException catch (error) {
      errorMessage = error.message;
      status = SessionStatus.passwordChangeRequired;
    } catch (_) {
      errorMessage = 'No fue posible conectar con el servidor.';
      status = SessionStatus.passwordChangeRequired;
    }

    notifyListeners();
  }

  Future<void> logout() async {
    final token = _token;
    try {
      if (token != null) await _api.logout(token);
    } finally {
      await _clearStoredSession();
      user = null;
      _token = null;
      errorMessage = null;
      status = SessionStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<void> _saveSession() async {
    await _storage.write(key: _tokenKey, value: _token);
    await _storage.write(key: _userKey, value: jsonEncode(user!.toJson()));
  }

  Future<void> _clearStoredSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }
}

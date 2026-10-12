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

  /// Se ejecuta al cerrar o perder la sesión para borrar lo que quede del
  /// usuario en el dispositivo (cola de sincronización y caché).
  Future<void> Function()? onSessionCleared;

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
        notifyListeners();
        await _descartarSesionRevocada(token);
        return;
      }
      status = SessionStatus.unauthenticated;
    } catch (_) {
      await _clearStoredSession();
      status = SessionStatus.unauthenticated;
    }

    notifyListeners();
  }

  /// Si el token ya no vale (cuenta desactivada o contraseña restablecida) hay
  /// que volver al login en lugar de dejar una app en la que todo falla. Un
  /// fallo de red no cierra la sesión: la app funciona sin conexión.
  Future<void> _descartarSesionRevocada(String token) async {
    try {
      await _api.verificarSesion(token);
    } on ApiException catch (error) {
      if (error.isUnauthenticated) {
        errorMessage = 'Su sesión expiró. Vuelva a ingresar.';
        await handleSessionExpired();
      }
    } catch (_) {
      // Sin conexión: se conserva la sesión para poder trabajar offline.
    }
  }

  /// Cierra la sesión local sin llamar al servidor, que ya rechazó el token.
  Future<void> handleSessionExpired() async {
    if (status == SessionStatus.unauthenticated) return;
    await _clearStoredSession();
    await onSessionCleared?.call();
    user = null;
    _token = null;
    status = SessionStatus.unauthenticated;
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

  Future<void> changePassword(
    String passwordActual,
    String passwordNueva,
    String confirmation,
  ) async {
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
        passwordActual: passwordActual,
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
    } catch (_) {
      // Aunque el servidor no responda, la sesión se cierra en el dispositivo.
    } finally {
      await _clearStoredSession();
      // En una tablet compartida, los datos del turno anterior no deben
      // quedar disponibles para el siguiente usuario.
      await onSessionCleared?.call();
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

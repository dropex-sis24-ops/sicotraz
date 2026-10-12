import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/authenticated_api_client.dart';
import 'core/theme/app_theme.dart';
import 'core/sync/sync_controller.dart';
import 'core/sync/sync_status_banner.dart';
import 'features/auth/application/session_controller.dart';
import 'features/auth/presentation/force_password_change_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/presentation/role_home_screen.dart';

void main() {
  final session = SessionController();
  final sync = SyncController();

  // Al cerrar o perder la sesión se borran la cola y la caché del dispositivo:
  // en una tablet compartida no deben pasar al turno siguiente.
  session.onSessionCleared = sync.clearDeviceData;
  // Un 401 desde cualquier pantalla devuelve al login en lugar de dejar la app
  // en un estado en el que todas las operaciones fallan.
  AuthenticatedApiClient.onUnauthenticated = session.handleSessionExpired;

  session.restore();
  runApp(SicotrazApp(session: session, sync: sync));
}

class SicotrazApp extends StatelessWidget {
  const SicotrazApp({super.key, this.session, this.sync});

  final SessionController? session;
  final SyncController? sync;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionController>(
          create: (_) => session ?? SessionController(),
        ),
        ChangeNotifierProvider<SyncController>(
          create: (_) => sync ?? SyncController(),
        ),
      ],
      child: MaterialApp(
        title: 'SICOTRAZ',
        theme: AppTheme.light,
        builder: (context, child) {
          final authenticated =
              context.watch<SessionController>().status ==
              SessionStatus.authenticated;
          if (!authenticated) return child!;
          return Column(
            children: [
              const SyncStatusBanner(),
              Expanded(child: child!),
            ],
          );
        },
        home: const _SessionGate(),
      ),
    );
  }
}

class _SessionGate extends StatelessWidget {
  const _SessionGate();

  @override
  Widget build(BuildContext context) {
    switch (context.watch<SessionController>().status) {
      case SessionStatus.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case SessionStatus.unauthenticated:
        return const LoginScreen();
      case SessionStatus.passwordChangeRequired:
        return const ForcePasswordChangeScreen();
      case SessionStatus.authenticated:
        return const RoleHomeScreen();
    }
  }
}

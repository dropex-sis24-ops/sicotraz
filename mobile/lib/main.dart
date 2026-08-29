import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/application/session_controller.dart';
import 'features/auth/presentation/force_password_change_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/presentation/role_home_screen.dart';

void main() {
  final session = SessionController()..restore();
  runApp(SicotrazApp(session: session));
}

class SicotrazApp extends StatelessWidget {
  const SicotrazApp({super.key, this.session});

  final SessionController? session;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SessionController>(
      create: (_) => session ?? SessionController(),
      child: MaterialApp(
        title: 'SICOTRAZ',
        theme: AppTheme.light,
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

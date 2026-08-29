import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/session_controller.dart';

class ForcePasswordChangeScreen extends StatefulWidget {
  const ForcePasswordChangeScreen({super.key});

  @override
  State<ForcePasswordChangeScreen> createState() =>
      _ForcePasswordChangeScreenState();
}

class _ForcePasswordChangeScreenState extends State<ForcePasswordChangeScreen> {
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  bool get _validPassword {
    final password = _passwordController.text;
    return password.length >= 8 &&
        password.length <= 30 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(password) &&
        password == _confirmationController.text;
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final loading = session.status == SessionStatus.loading;

    return Scaffold(
      appBar: AppBar(title: const Text('Cambio de contraseña obligatorio')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Este es tu primer ingreso. Debes crear una nueva contraseña.',
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _passwordController,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Contraseña nueva'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmationController,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Repetir contraseña',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Mínimo 8 y máximo 30 caracteres; al menos una mayúscula, una minúscula, un número y un símbolo.',
            ),
            if (session.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                session.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: loading || !_validPassword
                  ? null
                  : () => context.read<SessionController>().changePassword(
                      _passwordController.text,
                      _confirmationController.text,
                    ),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }
}

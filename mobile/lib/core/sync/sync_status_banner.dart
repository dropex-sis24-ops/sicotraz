import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'sync_controller.dart';

class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncController>();
    final (icon, color, text) = sync.conflictCount > 0
        ? (
            Icons.warning_amber,
            Colors.orange.shade900,
            '${sync.conflictCount} conflicto(s) pendientes de revisión',
          )
        : switch (sync.state) {
            SyncState.offline => (
              Icons.cloud_off,
              Colors.red.shade700,
              'Sin conexión — ${sync.pendingCount} pendientes',
            ),
            SyncState.syncing => (
              Icons.sync,
              Colors.orange.shade800,
              'Sincronizando ${sync.pendingCount} pendientes…',
            ),
            SyncState.online => (
              Icons.cloud_done,
              Colors.green.shade700,
              sync.pendingCount == 0
                  ? 'Datos sincronizados'
                  : '${sync.pendingCount} pendientes',
            ),
          };
    return Material(
      color: color,
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: sync.pendingCount > 0 ? sync.synchronize : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    text,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

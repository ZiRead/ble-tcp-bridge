import 'package:flutter/material.dart';

import '../services/bridge_controller.dart';

/// Баннер с текущим статусом подключения к устройству.
class StatusBanner extends StatelessWidget {
  final BridgeController bridge;

  const StatusBanner({super.key, required this.bridge});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = bridge.connectionState;

    final (Color color, IconData icon, String text) = switch (state) {
      DeviceConnectionState.connected => (
          Colors.green,
          Icons.link,
          'Подключено: ${bridge.connectedDevice?.name ?? ''}',
        ),
      DeviceConnectionState.connecting => (
          Colors.orange,
          Icons.sync,
          'Подключение...',
        ),
      DeviceConnectionState.disconnected => (
          scheme.outline,
          Icons.link_off,
          'Устройство не подключено',
        ),
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
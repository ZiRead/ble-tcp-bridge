import 'package:flutter/material.dart';

import '../models/device_info.dart';

/// Карточка найденного устройства (BLE или USB).
class DeviceCard extends StatelessWidget {
  final DeviceInfo device;
  final bool isConnected;
  final bool isConnecting;
  final VoidCallback? onTap;

  const DeviceCard({
    super.key,
    required this.device,
    this.isConnected = false,
    this.isConnecting = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isBle = device.type == DeviceType.ble;

    final Color accent = isConnected
        ? scheme.primary
        : (isBle ? Colors.blue : Colors.teal);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.15),
          child: Icon(
            isBle ? Icons.bluetooth : Icons.usb,
            color: accent,
          ),
        ),
        title: Text(
          device.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          device.subtitle ?? (isBle ? 'BLE устройство' : 'USB устройство'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isConnecting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : isConnected
                ? Icon(Icons.check_circle, color: scheme.primary)
                : Icon(Icons.chevron_right, color: scheme.outline),
      ),
    );
  }
}
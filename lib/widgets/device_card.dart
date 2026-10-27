import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/device_info.dart';
import '../services/settings_controller.dart';

/// Карточка найденного устройства (BLE, Classic или USB).
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
    final s = context.watch<SettingsController>().s;
    final settings = context.watch<SettingsController>();

    final isBle = device.type == DeviceType.ble;
    final isClassic = device.type == DeviceType.classic;

    final disabled = !device.serialCapable && settings.disableNonSerialDevices;

    final Color accent = isConnected
        ? scheme.primary
        : (isBle || isClassic ? Colors.blue : Colors.teal);

    final defaultLabel = switch (device.type) {
      DeviceType.ble => s.bleDeviceFallback,
      DeviceType.classic => s.classicDeviceLabel,
      DeviceType.usb => s.usbDeviceLabel,
    };

    // Метка типа устройства
    final typeLabel = switch (device.type) {
      DeviceType.ble => 'BLE',
      DeviceType.classic => 'Classic',
      DeviceType.usb => 'USB',
    };

    final hasAddress = device.address != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: disabled ? null : onTap,
        enabled: !disabled,
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.15),
          child: Icon(
            isBle || isClassic ? Icons.bluetooth : Icons.usb,
            color: accent,
          ),
        ),
        title: Text(
          device.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        isThreeLine: hasAddress,
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$typeLabel • ${device.subtitle ?? defaultLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (hasAddress)
              Text(
                device.address!,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: scheme.outline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
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

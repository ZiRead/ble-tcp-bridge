import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/device_info.dart';
import '../services/bridge_controller.dart';
import '../services/settings_controller.dart';
import '../widgets/status_banner.dart';

/// Вкладка «TCP сервер»: запуск локального TCP-сервера на порту 8080
/// и проброс данных между serial-устройством и TCP-клиентами.
class TcpScreen extends StatefulWidget {
  const TcpScreen({super.key});

  @override
  State<TcpScreen> createState() => _TcpScreenState();
}

class _TcpScreenState extends State<TcpScreen> {
  final TextEditingController _portController =
      TextEditingController(text: '8080');

  List<String> _localIps = <String>[];

  @override
  void initState() {
    super.initState();
    _loadLocalIp();
  }

  Future<void> _loadLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      final ips = <String>[];
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final ip = addr.address;
          if (!ips.contains(ip)) ips.add(ip);
        }
      }
      if (mounted) setState(() => _localIps = ips);
    } catch (_) {}
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  Future<void> _toggleServer(BridgeController bridge) async {
    final s = context.read<SettingsController>().s;
    if (bridge.tcpRunning) {
      await bridge.stopTcpServer();
    } else {
      final port = int.tryParse(_portController.text.trim()) ?? 8080;
      if (port < 1 || port > 65535) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.invalidPort)),
        );
        return;
      }
      await bridge.startTcpServer(port: port);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bridge = context.watch<BridgeController>();
    final s = context.watch<SettingsController>().s;
    final scheme = Theme.of(context).colorScheme;
    final running = bridge.tcpRunning;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.tabTcp),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          StatusBanner(bridge: bridge),

          // ===== Карточка сервера =====
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: running ? Colors.green : scheme.outline,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        running ? s.serverRunning : s.serverStopped,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: running ? Colors.green : scheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      if (running)
                        Chip(
                          label: Text(s.clients(bridge.tcpClients)),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Порт
                  Row(
                    children: [
                      Icon(Icons.dns, size: 20, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(s.labelPort),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _portController,
                          enabled: !running,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            hintText: '8080',
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // IP адрес
                  Row(
                    children: [
                      Icon(Icons.lan, size: 20, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(s.labelAddress),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (running && _localIps.isNotEmpty)
                              for (final ip in _localIps)
                                Text(
                                  '$ip:${bridge.tcpPort}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                            else if (running)
                              Text(
                                '0.0.0.0:${bridge.tcpPort}',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            else
                              const Text('—'),
                            if (running)
                              Text(
                                'localhost:${bridge.tcpPort}',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: scheme.outline,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Кнопка
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _toggleServer(bridge),
                      icon: Icon(running ? Icons.stop : Icons.play_arrow),
                      label: Text(running ? s.btnStopServer : s.btnStartServer),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            running ? scheme.error : scheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),

                  if (!running &&
                      bridge.connectionState != DeviceConnectionState.connected)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        s.tipConnectDevice,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.outline,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ===== Статистика =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _statCard(
                  scheme,
                  icon: Icons.south,
                  label: s.statFromDevice,
                  value: '${bridge.bytesFromDevice} Б',
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                _statCard(
                  scheme,
                  icon: Icons.north,
                  label: s.statToDevice,
                  value: '${bridge.bytesToDevice} Б',
                  color: Colors.blue,
                ),
              ],
            ),
          ),

          // ===== Лог =====
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
            child: Row(
              children: [
                Icon(Icons.receipt_long, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.logTitle,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: bridge.clearLogs,
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: Text(s.btnClear),
                ),
              ],
            ),
          ),

          if (bridge.logs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  s.logEmpty,
                  style: TextStyle(color: scheme.outline, fontSize: 13),
                ),
              ),
            )
          else
            for (final log in bridge.logs.reversed) _logTile(log),
        ],
      ),
    );
  }

  Widget _statCard(
    ColorScheme scheme, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: scheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logTile(BridgeLog log) {
    final scheme = Theme.of(context).colorScheme;
    final color = log.isError ? scheme.error : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            log.timeLabel,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: scheme.outline,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              log.message,
              style: TextStyle(fontSize: 12.5, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

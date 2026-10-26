import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../models/device_info.dart';
import '../services/bridge_controller.dart';
import '../services/settings_controller.dart';
import '../widgets/device_card.dart';
import '../widgets/status_banner.dart';

/// Вкладка «Устройства»: поиск BLE, Bluetooth Classic и USB устройств,
/// подключение.
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final List<DeviceInfo> _btDevices = [];
  final List<DeviceInfo> _usbDevices = [];

  bool _bleScanning = false;
  bool _classicSearching = false;
  bool _usbLoading = false;
  bool _connecting = false;

  /// Фильтр: показывать только устройства, пригодные для serial-обмена.
  bool _bleSerialOnly = false;

  String? _error;

  StreamSubscription? _bleFoundSub;
  StreamSubscription? _bleErrorSub;
  StreamSubscription? _adapterSub;
  StreamSubscription? _classicFoundSub;
  StreamSubscription? _classicErrorSub;
  StreamSubscription? _classicStateSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final bridge = context.read<BridgeController>();

    _bleFoundSub = bridge.bleService.onDeviceFound.listen((d) {
      if (!mounted) return;
      setState(() {
        final idx =
            _btDevices.indexWhere((e) => e.type == d.type && e.id == d.id);
        if (idx >= 0) {
          _btDevices[idx] = d;
        } else {
          _btDevices.add(d);
        }
      });
    });

    _bleErrorSub = bridge.bleService.onError.listen((msg) {
      if (!mounted) return;
      setState(() => _error = msg);
    });

    _adapterSub = bridge.bleService.onAdapterState.listen((state) {
      if (!mounted) return;
      if (state == BluetoothAdapterState.off) {
        setState(() =>
            _error = context.read<SettingsController>().s.errorBluetoothOff);
      } else if (state == BluetoothAdapterState.on) {
        setState(() => _error = null);
      }
    });

    // Bluetooth Classic
    _classicFoundSub = bridge.classicService.onDeviceFound.listen((d) {
      if (!mounted) return;
      setState(() {
        final idx =
            _btDevices.indexWhere((e) => e.type == d.type && e.id == d.id);
        if (idx >= 0) {
          _btDevices[idx] = d;
        } else {
          _btDevices.add(d);
        }
      });
    });

    _classicErrorSub = bridge.classicService.onError.listen((msg) {
      if (!mounted) return;
      setState(() => _error = msg);
    });

    _classicStateSub = bridge.classicService.onEnabledChanged.listen((enabled) {
      if (!mounted) return;
      if (!enabled) {
        setState(() =>
            _error = context.read<SettingsController>().s.errorBluetoothOff);
      }
    });

    bridge.bleService.listenAdapterState();
    bridge.classicService.listenAdapterState();
    await _loadUsbDevices();
  }

  // ================= Разрешения =================

  Future<bool> _ensureBlePermissions({bool classicDiscovery = false}) async {
    final bridge = context.read<BridgeController>();
    final s = context.read<SettingsController>().s;

    if (!await bridge.bleService.ensureReady()) return false;

    var status = await Permission.bluetoothScan.status;
    if (!status.isGranted) {
      status = await Permission.bluetoothScan.request();
    }
    if (!status.isGranted) {
      setState(() => _error = s.errorBleScan);
      return false;
    }

    status = await Permission.bluetoothConnect.status;
    if (!status.isGranted) {
      status = await Permission.bluetoothConnect.request();
    }
    if (!status.isGranted) {
      setState(() => _error = s.errorBleConnect);
      return false;
    }

    // Разрешение на местоположение требуется:
    //   - всегда для поиска Classic-устройств (плагин flutter_bluetooth_serial
    //     проверяет ACCESS_COARSE/FINE_LOCATION на всех версиях Android);
    //   - на Android ≤ 11 (API ≤ 30) для BLE-сканирования.
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final needLocation = classicDiscovery || androidInfo.version.sdkInt <= 30;
    if (needLocation) {
      final locStatus = await Permission.location.status;
      if (!locStatus.isGranted) {
        final loc = await Permission.location.request();
        if (!loc.isGranted) {
          setState(() => _error = s.errorLocation);
          return false;
        }
      }
    }

    return true;
  }

  // ================= BLE =================

  Future<void> _toggleBleScan() async {
    final bridge = context.read<BridgeController>();

    if (_bleScanning) {
      await bridge.bleService.stopScan();
      setState(() => _bleScanning = false);
      return;
    }

    setState(() {
      _bleScanning = true;
      _error = null;
      _btDevices.clear();
    });

    if (!await _ensureBlePermissions()) {
      setState(() => _bleScanning = false);
      return;
    }

    try {
      await bridge.bleService.startScan(filterSerialOnly: _bleSerialOnly);
    } catch (_) {
      setState(() => _bleScanning = false);
      return;
    }

    // Автоостановка по таймауту сканирования
    Future.delayed(const Duration(seconds: 13), () {
      if (mounted && _bleScanning) {
        setState(() => _bleScanning = false);
      }
    });
  }

  /// Переключатель фильтра «Только Serial».
  Future<void> _toggleBleFilter(bool value) async {
    final bridge = context.read<BridgeController>();
    final wasScanning = _bleScanning;

    setState(() {
      _bleSerialOnly = value;
      _btDevices.clear();
    });

    // Если скан шёл — перезапускаем его с новым фильтром
    if (wasScanning) {
      await bridge.bleService.stopScan();
      await _toggleBleScan();
    } else {
      setState(() => _error = null);
    }
  }

  /// Общий поиск Bluetooth: запускает/останавливает сканирование BLE
  /// и поиск Classic одновременно.
  Future<void> _toggleBtScan() async {
    final bridge = context.read<BridgeController>();

    final scanning = _bleScanning || _classicSearching;
    if (scanning) {
      await Future.wait([
        bridge.bleService.stopScan(),
        bridge.classicService.stopDiscovery(),
      ]);
      setState(() {
        _bleScanning = false;
        _classicSearching = false;
      });
      return;
    }

    setState(() {
      _bleScanning = true;
      _classicSearching = true;
      _error = null;
      _btDevices.clear();
    });

    if (!await _ensureBlePermissions(classicDiscovery: true)) {
      setState(() {
        _bleScanning = false;
        _classicSearching = false;
      });
      return;
    }

    try {
      await Future.wait([
        bridge.bleService.startScan(filterSerialOnly: _bleSerialOnly),
        bridge.classicService.startDiscovery(filterSerialOnly: _bleSerialOnly),
      ]);
    } catch (_) {
      setState(() {
        _bleScanning = false;
        _classicSearching = false;
      });
    }

    // Автоостановка по таймауту
    Future.delayed(const Duration(seconds: 13), () {
      if (!mounted) return;
      if (_bleScanning) bridge.bleService.stopScan();
      if (_classicSearching) bridge.classicService.stopDiscovery();
      setState(() {
        _bleScanning = false;
        _classicSearching = false;
      });
    });
  }

  // ================= USB =================

  Future<void> _loadUsbDevices() async {
    final bridge = context.read<BridgeController>();
    setState(() => _usbLoading = true);

    try {
      final devices = await bridge.usbService.listDevices();
      if (!mounted) return;
      setState(() {
        _usbDevices
          ..clear()
          ..addAll(devices);
        _usbLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _usbLoading = false;
        _error = '${context.read<SettingsController>().s.errorUsbList}: $e';
      });
    }
  }

  // ================= Подключение =================

  Future<void> _connect(DeviceInfo device) async {
    final bridge = context.read<BridgeController>();
    if (_connecting) return;

    setState(() {
      _connecting = true;
      _error = null;
    });

    final ok = await bridge.connect(device);
    if (!mounted) return;

    setState(() {
      _connecting = false;
      _bleScanning = false;
      _classicSearching = false;
      if (!ok) {
        _error =
            context.read<SettingsController>().s.connectFailed(device.name);
      }
    });
  }

  Future<void> _disconnect() async {
    final bridge = context.read<BridgeController>();
    await bridge.disconnect();
  }

  @override
  void dispose() {
    _bleFoundSub?.cancel();
    _bleErrorSub?.cancel();
    _adapterSub?.cancel();
    _classicFoundSub?.cancel();
    _classicErrorSub?.cancel();
    _classicStateSub?.cancel();
    super.dispose();
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final bridge = context.watch<BridgeController>();
    final s = context.watch<SettingsController>().s;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.tabDevices),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadUsbDevices();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            StatusBanner(bridge: bridge),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: scheme.onErrorContainer, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: scheme.onErrorContainer,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ===== Bluetooth секция (общий поиск BLE + Classic) =====
            _sectionHeader(
              context,
              icon: Icons.bluetooth,
              title: s.secBt,
              action: _scanButton(
                label:
                    (_bleScanning || _classicSearching) ? s.btnStop : s.btnScan,
                isActive: _bleScanning || _classicSearching,
                onTap: _toggleBtScan,
              ),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              secondary: Icon(
                Icons.filter_alt_outlined,
                color: _bleSerialOnly ? scheme.primary : scheme.outline,
              ),
              title: Text(
                s.filterTitle,
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: Text(
                s.filterSubtitle,
                style: const TextStyle(fontSize: 12),
              ),
              value: _bleSerialOnly,
              onChanged: _toggleBleFilter,
            ),

            if (_btDevices.isEmpty && !_bleScanning && !_classicSearching)
              _emptyHint(
                context,
                icon: Icons.bluetooth_searching,
                text: _bleSerialOnly ? s.emptyBleFiltered : s.emptyBt,
              ),

            for (final d in _btDevices)
              DeviceCard(
                device: d,
                isConnected: bridge.connectedDevice?.id == d.id &&
                    bridge.connectionState == DeviceConnectionState.connected,
                isConnecting: _connecting && bridge.connectedDevice?.id == d.id,
                onTap: () => _connect(d),
              ),

            const SizedBox(height: 12),

            // ===== USB секция =====
            _sectionHeader(
              context,
              icon: Icons.usb,
              title: s.secUsb,
              action: _scanButton(
                label: s.btnRefresh,
                isActive: _usbLoading,
                onTap: _usbLoading ? null : _loadUsbDevices,
              ),
            ),

            if (_usbDevices.isEmpty && !_usbLoading)
              _emptyHint(
                context,
                icon: Icons.usb_off,
                text: s.emptyUsb,
              ),

            for (final d in _usbDevices)
              DeviceCard(
                device: d,
                isConnected: bridge.connectedDevice?.id == d.id &&
                    bridge.connectionState == DeviceConnectionState.connected,
                isConnecting: _connecting && bridge.connectedDevice?.id == d.id,
                onTap: () => _connect(d),
              ),

            // ===== Кнопка отключения =====
            if (bridge.connectionState == DeviceConnectionState.connected)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                child: FilledButton.tonalIcon(
                  onPressed: _disconnect,
                  icon: const Icon(Icons.link_off),
                  label: Text(s.btnDisconnect),
                  style: FilledButton.styleFrom(
                    foregroundColor: scheme.error,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _scanButton({
    String? label,
    required bool isActive,
    required VoidCallback? onTap,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      icon: isActive
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.search, size: 18),
      label: Text(label ?? ''),
    );
  }

  Widget _sectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget action,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
          action,
        ],
      ),
    );
  }

  Widget _emptyHint(BuildContext context,
      {required IconData icon, required String text}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Column(
        children: [
          Icon(icon, size: 40, color: scheme.outline),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.outline, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

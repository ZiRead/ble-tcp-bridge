import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../models/device_info.dart';
import '../services/bridge_controller.dart';
import '../widgets/device_card.dart';
import '../widgets/status_banner.dart';

/// Вкладка «Устройства»: поиск BLE и USB устройств, подключение.
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final List<DeviceInfo> _bleDevices = [];
  final List<DeviceInfo> _usbDevices = [];

  bool _bleScanning = false;
  bool _usbLoading = false;
  bool _connecting = false;

  /// Фильтр: показывать только устройства, пригодные для serial-обмена.
  bool _bleSerialOnly = false;

  String? _error;

  StreamSubscription? _bleFoundSub;
  StreamSubscription? _bleErrorSub;
  StreamSubscription? _adapterSub;

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
        final idx = _bleDevices.indexWhere((e) => e.id == d.id);
        if (idx >= 0) {
          _bleDevices[idx] = d;
        } else {
          _bleDevices.add(d);
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
        setState(() => _error = 'Bluetooth выключен. Включите Bluetooth');
      } else if (state == BluetoothAdapterState.on) {
        setState(() => _error = null);
      }
    });

    bridge.bleService.listenAdapterState();
    await _loadUsbDevices();
  }

  // ================= Разрешения =================

  Future<bool> _ensureBlePermissions() async {
    final bridge = context.read<BridgeController>();

    if (!await bridge.bleService.ensureReady()) return false;

    var status = await Permission.bluetoothScan.status;
    if (!status.isGranted) {
      status = await Permission.bluetoothScan.request();
    }
    if (!status.isGranted) {
      setState(() => _error = 'Нет разрешения на сканирование BLE. '
          'Выдайте его: Настройки → Приложения → BLE/USB TCP Bridge → Разрешения');
      return false;
    }

    status = await Permission.bluetoothConnect.status;
    if (!status.isGranted) {
      status = await Permission.bluetoothConnect.request();
    }
    if (!status.isGranted) {
      setState(() => _error = 'Нет разрешения на подключение BLE');
      return false;
    }

    // Разрешение на местоположение требуется ТОЛЬКО для Android ≤ 11 (API ≤ 30).
    // На Android 12+ BLE-скан выполняется через BLUETOOTH_SCAN
    // с флагом neverForLocation, поэтому местоположение не нужно.
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt <= 30) {
      final locStatus = await Permission.location.status;
      if (!locStatus.isGranted) {
        final loc = await Permission.location.request();
        if (!loc.isGranted) {
          setState(() => _error = 'Для BLE-сканирования нужно разрешение '
              'на местоположение (Android 11 и ниже)');
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
      _bleDevices.clear();
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
      _bleDevices.clear();
    });

    // Если скан шёл — перезапускаем его с новым фильтром
    if (wasScanning) {
      await bridge.bleService.stopScan();
      await _toggleBleScan();
    } else {
      setState(() => _error = null);
    }
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
        _error = 'Ошибка чтения USB устройств: $e';
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
      if (!ok) {
        _error = 'Не удалось подключиться к "${device.name}"';
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
    super.dispose();
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final bridge = context.watch<BridgeController>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Устройства'),
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

            // ===== BLE секция =====
            _sectionHeader(
              context,
              icon: Icons.bluetooth,
              title: 'BLE устройства',
              action: TextButton.icon(
                onPressed: _toggleBleScan,
                icon: _bleScanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_bleScanning ? Icons.stop : Icons.search, size: 18),
                label: Text(_bleScanning ? 'Стоп' : 'Сканировать'),
              ),
            ),

            // Переключатель фильтра: только Serial-устройства
            SwitchListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              secondary: Icon(
                Icons.filter_alt_outlined,
                color: _bleSerialOnly
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
              title: const Text(
                'Только Serial-устройства',
                style: TextStyle(fontSize: 14),
              ),
              subtitle: const Text(
                'Показывать только BLE Serial / Nordic UART',
                style: TextStyle(fontSize: 12),
              ),
              value: _bleSerialOnly,
              onChanged: _toggleBleFilter,
            ),

            if (_bleDevices.isEmpty && !_bleScanning)
              _emptyHint(
                context,
                icon: Icons.bluetooth_searching,
                text: _bleSerialOnly
                    ? 'Нажмите «Сканировать».\n'
                        'Фильтр «Только Serial» активен — будут показаны лишь '
                        'устройства BLE Serial (HM-10, HC-08, Nordic UART и т.п.).'
                    : 'Нажмите «Сканировать», чтобы найти BLE устройства.\n'
                        'Поддерживаются BLE Serial (HM-10, HC-08, NUS).',
              ),
            for (final d in _bleDevices)
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
              title: 'USB устройства',
              action: TextButton.icon(
                onPressed: _usbLoading ? null : _loadUsbDevices,
                icon: _usbLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: const Text('Обновить'),
              ),
            ),

            if (_usbDevices.isEmpty && !_usbLoading)
              _emptyHint(
                context,
                icon: Icons.usb_off,
                text: 'Подключите USB UART адаптер (CH340, CP2102, FTDI, '
                    'PL2303 и др.) через OTG-кабель.',
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
                  label: const Text('Отключить устройство'),
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

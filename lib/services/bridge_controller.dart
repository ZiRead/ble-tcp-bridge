import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/device_info.dart';
import 'ble_service.dart';
import 'bt_classic_service.dart';
import 'foreground_service.dart';
import 'serial_port.dart';
import 'settings_controller.dart';
import 'tcp_server_service.dart';
import 'usb_service.dart';

/// Состояние подключения к устройству.
enum DeviceConnectionState { disconnected, connecting, connected }

/// Центральный контроллер моста: управляет подключением к устройству
/// (BLE или USB) и TCP-сервером, пробрасывая данные между ними.
class BridgeController extends ChangeNotifier {
  final BleService bleService;
  final BtClassicService classicService;
  final UsbService usbService;
  final TcpServerService tcpServer;
  final SettingsController? settings;

  BridgeController({
    required this.bleService,
    required this.classicService,
    required this.usbService,
    required this.tcpServer,
    this.settings,
  }) {
    _init();
  }

  // ---- Состояние подключения ----
  DeviceConnectionState _connectionState = DeviceConnectionState.disconnected;
  DeviceConnectionState get connectionState => _connectionState;

  DeviceInfo? _connectedDevice;
  DeviceInfo? get connectedDevice => _connectedDevice;

  SerialPort? _port;
  SerialPort? get port => _port;

  StreamSubscription? _portSub;
  StreamSubscription? _tcpSub;

  // ---- Логи и статистика ----
  final List<BridgeLog> _logs = [];
  List<BridgeLog> get logs => List.unmodifiable(_logs);

  final List<DataPacket> _packets = [];
  List<DataPacket> get packets => List.unmodifiable(_packets);

  int _bytesFromDevice = 0;
  int _bytesToDevice = 0;
  int get bytesFromDevice => _bytesFromDevice;
  int get bytesToDevice => _bytesToDevice;

  bool _tcpRunning = false;
  bool get tcpRunning => _tcpRunning;
  int get tcpPort => tcpServer.port;
  int get tcpClients => tcpServer.clientCount;

  void _init() {
    // Данные от TCP-клиентов -> в serial устройство
    _tcpSub = tcpServer.onDataFromClients.listen((data) async {
      _addPacket(data, fromDevice: false);
      _bytesToDevice += data.length;
      notifyListeners();
      try {
        await _port?.write(data);
      } catch (e) {
        _addLog('Ошибка записи в устройство: $e', isError: true);
      }
    });

    // События TCP-сервера -> в лог
    tcpServer.onEvent.listen((msg) {
      _addLog(msg);
      notifyListeners();
    });
  }

  // ================= Подключение к устройству =================

  /// Подключиться к выбранному устройству (BLE или USB).
  Future<bool> connect(DeviceInfo device) async {
    await disconnect();
    _connectionState = DeviceConnectionState.connecting;
    _connectedDevice = device;
    _addLog(settings?.s.logConnectingToDevice(device.name) ??
        'Подключение к "${device.name}"...');
    notifyListeners();

    try {
      SerialPort port;
      switch (device.type) {
        case DeviceType.ble:
          port = await bleService.connect(device);
          break;
        case DeviceType.classic:
          port = await classicService.connect(device);
          break;
        case DeviceType.usb:
          port = await usbService.connect(
            device,
            baudRate: settings?.usbBaudRate ?? 115200,
          );
          break;
      }
      _port = port;
      _connectionState = DeviceConnectionState.connected;
      _addLog(settings?.s.logConnected(port.label) ?? 'Подключено: ${port.label}');

      if (_tcpRunning) {
        TcpForegroundService.update(
          title: settings?.s.serverRunning ?? 'TCP server running',
          text: 'Port $tcpPort • Clients: $tcpClients',
          bigText:
              '${settings?.s.serverRunning ?? 'TCP server running'}\n'
              'Port: $tcpPort\n'
              'Clients: $tcpClients\n'
              'Device: ${device.name}\n'
              'Address: ${device.address ?? device.id}',
        );
      }

      // Данные от устройства -> всем TCP-клиентам
      _portSub = port.inputStream.listen((data) {
        _bytesFromDevice += data.length;
        _addPacket(data, fromDevice: true);
        tcpServer.broadcast(data);
        notifyListeners();
      });

      notifyListeners();
      return true;
    } catch (e) {
      _connectionState = DeviceConnectionState.disconnected;
      _connectedDevice = null;
      _addLog(settings?.s.logConnectError(e) ?? 'Ошибка подключения: $e', isError: true);
      notifyListeners();
      return false;
    }
  }

  /// Отключиться от устройства.
  Future<void> disconnect() async {
    await _portSub?.cancel();
    _portSub = null;
    await _port?.close();
    _port = null;
    if (_connectionState != DeviceConnectionState.disconnected) {
      _addLog(settings?.s.logDisconnected ?? 'Устройство отключено');
    }
    _connectionState = DeviceConnectionState.disconnected;
    _connectedDevice = null;
    if (_tcpRunning) {
      TcpForegroundService.update(
        title: settings?.s.serverRunning ?? 'TCP server running',
        text: 'Port $tcpPort • Clients: $tcpClients',
        bigText:
            '${settings?.s.serverRunning ?? 'TCP server running'}\n'
            'Port: $tcpPort\n'
            'Clients: $tcpClients\n'
            'Device: none',
      );
    }
    notifyListeners();
  }

  // ================= TCP сервер =================

  Future<bool> startTcpServer({int port = TcpServerService.defaultPort}) async {
    try {
      await tcpServer.start(port: port);
      _tcpRunning = true;
      notifyListeners();
      // Обновить уведомление с данными устройства, если оно подключено
      if (_connectedDevice != null) {
        TcpForegroundService.update(
          title: settings?.s.serverRunning ?? 'TCP server running',
          text: 'Port $tcpPort • Clients: $tcpClients',
          bigText:
              '${settings?.s.serverRunning ?? 'TCP server running'}\n'
              'Port: $tcpPort\n'
              'Clients: $tcpClients\n'
              'Device: ${_connectedDevice!.name}\n'
              'Address: ${_connectedDevice!.address ?? _connectedDevice!.id}',
        );
      }
      return true;
    } catch (e) {
      _addLog('Не удалось запустить TCP сервер: $e', isError: true);
      notifyListeners();
      return false;
    }
  }

  Future<void> stopTcpServer() async {
    await tcpServer.stop();
    _tcpRunning = false;
    notifyListeners();
  }

  // ================= Логи =================

  void _addLog(String message, {bool isError = false}) {
    _logs.add(BridgeLog(message, isError: isError));
    if (_logs.length > 500) {
      _logs.removeRange(0, _logs.length - 500);
    }
  }

  void _addPacket(Uint8List data, {required bool fromDevice}) {
    _packets.add(DataPacket(data, fromDevice: fromDevice));
    if (_packets.length > 300) {
      _packets.removeRange(0, _packets.length - 300);
    }
  }

  void clearLogs() {
    _logs.clear();
    _packets.clear();
    _bytesFromDevice = 0;
    _bytesToDevice = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _portSub?.cancel();
    _tcpSub?.cancel();
    super.dispose();
  }
}

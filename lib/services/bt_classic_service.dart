import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import '../models/device_info.dart';
import 'settings_controller.dart';
import 'serial_port.dart';

/// Реализация [SerialPort] поверх Bluetooth Classic (SPP, RFCOMM).
///
/// Используется для модулей HC-05 / HC-06 и аналогичных.
class BtClassicSerialPort implements SerialPort {
  final BluetoothConnection _connection;
  final String _label;

  BtClassicSerialPort._(this._connection, this._label);

  @override
  Stream<Uint8List> get inputStream =>
      _connection.input ?? const Stream.empty();

  @override
  Future<void> write(Uint8List data) async {
    _connection.output.add(data);
    try {
      await _connection.output.allSent;
    } catch (_) {}
  }

  @override
  Future<void> close() async {
    try {
      await _connection.close();
    } catch (_) {}
  }

  @override
  String get label => _label;
}

/// Сервис для работы с Bluetooth Classic (SPP): сканирование и подключение.
class BtClassicService {
  final SettingsController? settings;
  BtClassicService({this.settings});
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;

  final List<DeviceInfo> _devices = [];
  List<DeviceInfo> get devices => List.unmodifiable(_devices);

  StreamSubscription? _discoverySub;
  StreamSubscription? _stateSub;
  bool _discovering = false;
  bool get isDiscovering => _discovering;

  final _deviceStream = StreamController<DeviceInfo>.broadcast();
  final _errorStream = StreamController<String>.broadcast();
  final _stateStream = StreamController<bool>.broadcast();

  Stream<DeviceInfo> get onDeviceFound => _deviceStream.stream;
  Stream<String> get onError => _errorStream.stream;
  Stream<bool> get onEnabledChanged => _stateStream.stream;

  /// Проверить, включён ли Bluetooth.
  Future<bool> isEnabled() async {
    try {
      return await _bluetooth.isEnabled ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Признаки serial-модулей в именах Classic SPP устройств.
  static const List<String> _serialNameHints = [
    'hc-05',
    'hc05',
    'hc-06',
    'hc06',
    'serial',
    'uart',
    'spp',
    'jdy',
    'bt05',
    'ble-link',
    'tapnlink',
    'rn42',
    'rn41',
  ];

  /// Определяет, может ли Classic-устройство быть serial (SPP) модулем.
  ///
  /// Пакет не предоставляет BluetoothClass, поэтому эвристика по имени.
  static bool isSerialCapable(BluetoothDevice dev) {
    final name = (dev.name ?? '').toLowerCase().trim();
    if (name.isEmpty) return false;
    for (final hint in _serialNameHints) {
      if (name.contains(hint)) return true;
    }
    return false;
  }

  /// Подписка на состояние Bluetooth.
  void listenAdapterState() {
    _stateSub ??= _bluetooth.onStateChanged().listen((state) {
      _stateStream.add(state == BluetoothState.STATE_ON);
    });
  }

  /// Начать поиск Bluetooth Classic устройств (SPP).
  ///
  /// Если [filterSerialOnly] = true, показываются только устройства
  /// с признаками serial-модуля (HC-05, HC-06 и т.п.).
  Future<void> startDiscovery({bool filterSerialOnly = false}) async {
    if (_discovering) return;
    _devices.clear();
    _discovering = true;

    try {
      _discoverySub = _bluetooth.startDiscovery().listen((result) {
        final dev = result.device;
        if (filterSerialOnly && !isSerialCapable(dev)) {
          return; // отсеиваем неподходящие Classic-устройства
        }
        final name =
            (dev.name ?? '').trim().isNotEmpty ? (dev.name ?? '').trim() : (dev.address);
        final info = DeviceInfo(
          type: DeviceType.classic,
          id: dev.address,
          name: name,
          serialCapable: isSerialCapable(dev),
          subtitle: 'RSSI: ${result.rssi} dBm',
          address: dev.address,
          rssi: result.rssi,
          raw: dev,
        );
        final idx = _devices.indexWhere((d) => d.id == info.id);
        if (idx >= 0) {
          _devices[idx] = info;
        } else {
          _devices.add(info);
          _deviceStream.add(info);
        }
      }, onError: (e) {
        _errorStream.add(settings?.s.classicSearchError(e) ?? 'Ошибка поиска: $e');
      }, onDone: () {
        _discovering = false;
      });
    } catch (e) {
      _errorStream.add(settings?.s.classicStartError(e) ?? 'Не удалось начать поиск: $e');
      _discovering = false;
      rethrow;
    }
  }

  /// Остановить поиск.
  Future<void> stopDiscovery() async {
    _discovering = false;
    try {
      await _discoverySub?.cancel();
    } catch (_) {}
    try {
      await _bluetooth.cancelDiscovery();
    } catch (_) {}
    _discoverySub = null;
  }

  /// Подключиться к Classic-устройству по адресу (SPP / RFCOMM).
  Future<BtClassicSerialPort> connect(DeviceInfo info) async {
    await stopDiscovery();

    final address = info.id;
    final connection = await BluetoothConnection.toAddress(address);
    return BtClassicSerialPort._(connection, info.name);
  }

  void dispose() {
    _discoverySub?.cancel();
    _stateSub?.cancel();
    _deviceStream.close();
    _errorStream.close();
    _stateStream.close();
  }
}

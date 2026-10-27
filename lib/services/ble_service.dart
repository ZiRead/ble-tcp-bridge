import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/device_info.dart';
import 'serial_port.dart';

/// UUID сервисов BLE Serial, которые поддерживает приложение.
class BleSerialUuids {
  // HM-10 / HC-08 / CC2541 (популярные BLE Serial модули)
  static const String hm10Service = '0000ffe0-0000-1000-8000-00805f9b34fb';
  static const String hm10Characteristic =
      '0000ffe1-0000-1000-8000-00805f9b34fb';

  // Nordic UART Service (NUS) — используется многими BLE Serial устройствами
  static const String nusService = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const String nusTx = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
  static const String nusRx = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';

  static const List<String> knownServices = [hm10Service, nusService];

  /// Ключевые слова в именах популярных BLE Serial модулей.
  static const List<String> serialNameHints = [
    'hm-10',
    'hm10',
    'hc-08',
    'hc08',
    'at-09',
    'jdy',
    'mlt-bt05',
    'bt05',
    'bluno',
    'ble-serial',
    'ble serial',
    'uart',
    'serial',
    'cc2541',
    'cc2540',
    'hc-06',
    'hc06',
    'jd-08',
    'lk-bt',
    'tapnlink',
  ];

  /// Определяет, может ли найденное устройство использоваться для
  /// serial-обмена (BLE Serial / Nordic UART).
  ///
  /// Проверяет объявленные сервисы в рекламном пакете и имя устройства.
  static bool isSerialCapable(ScanResult r) {
    // 1) Известный serial-сервис в рекламе
    for (final uuid in r.advertisementData.serviceUuids) {
      final u = uuid.str.toLowerCase();
      if (u == BleSerialUuids.hm10Service || u == BleSerialUuids.nusService) {
        return true;
      }
    }

    // 2) Имя устройства содержит признаки serial-модуля
    final name =
        '${r.device.platformName} ${r.advertisementData.advName}'.toLowerCase();
    if (name.trim().isEmpty) return false;
    for (final hint in serialNameHints) {
      if (name.contains(hint)) return true;
    }

    return false;
  }
}

/// Реализация [SerialPort] поверх BLE-устройства.
class BleSerialPort implements SerialPort {
  final BluetoothDevice device;
  final BluetoothCharacteristic _tx; // запись в устройство
  final BluetoothCharacteristic _rx; // уведомления от устройства

  BleSerialPort(this.device, this._tx, this._rx);

  @override
  Stream<Uint8List> get inputStream =>
      _rx.onValueReceived.map((v) => Uint8List.fromList(v));

  @override
  Future<void> write(Uint8List data) async {
    // Разбиваем на куски по MTU (3 байта служебных)
    final mtu = device.mtuNow > 0 ? device.mtuNow : 23;
    final chunk = mtu - 3;
    for (var i = 0; i < data.length; i += chunk) {
      final end = (i + chunk < data.length) ? i + chunk : data.length;
      await _tx.write(data.sublist(i, end));
    }
  }

  @override
  Future<void> close() async {
    try {
      await _rx.setNotifyValue(false);
    } catch (_) {}
    try {
      await device.disconnect();
    } catch (_) {}
  }

  @override
  String get label => device.platformName.isNotEmpty
      ? device.platformName
      : device.remoteId.str;
}

/// Сервис для работы с BLE: сканирование, подключение, поиск BLE Serial.
class BleService {
  final List<DeviceInfo> _devices = [];
  List<DeviceInfo> get devices => List.unmodifiable(_devices);

  StreamSubscription? _scanSub;
  bool _scanning = false;
  bool get isScanning => _scanning;

  /// Поток событий: найденные устройства, ошибки, статус адаптера.
  final _deviceStream = StreamController<DeviceInfo>.broadcast();
  final _errorStream = StreamController<String>.broadcast();
  final _stateStream = StreamController<BluetoothAdapterState>.broadcast();

  Stream<DeviceInfo> get onDeviceFound => _deviceStream.stream;
  Stream<String> get onError => _errorStream.stream;
  Stream<BluetoothAdapterState> get onAdapterState => _stateStream.stream;

  /// Проверить поддержку BLE и запросить разрешения.
  Future<bool> ensureReady() async {
    try {
      if (await FlutterBluePlus.isSupported == false) {
        _errorStream.add('Bluetooth не поддерживается этим устройством');
        return false;
      }
      // Включаем Bluetooth, если выключен (Android)
      if (FlutterBluePlus.adapterStateNow == BluetoothAdapterState.off) {
        await FlutterBluePlus.turnOn();
      }
      return true;
    } catch (e) {
      _errorStream.add('Ошибка инициализации BLE: $e');
      return false;
    }
  }

  /// Подписка на состояние адаптера.
  void listenAdapterState() {
    FlutterBluePlus.adapterState.listen((state) {
      _stateStream.add(state);
    });
  }

  /// Начать сканирование BLE устройств.
  ///
  /// Если [filterSerialOnly] = true, в результаты попадают только устройства,
  /// пригодные для serial-обмена (BLE Serial / Nordic UART).
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 12),
    bool filterSerialOnly = false,
  }) async {
    if (_scanning) return;
    _devices.clear();
    _scanning = true;

    try {
      await FlutterBluePlus.startScan(timeout: timeout);
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          if (filterSerialOnly && !BleSerialUuids.isSerialCapable(r)) {
            continue; // отсеиваем неподходящие устройства
          }
          final name = r.device.platformName.trim().isNotEmpty
              ? r.device.platformName.trim()
              : (r.advertisementData.advName.trim().isNotEmpty
                  ? r.advertisementData.advName.trim()
                  : r.device.remoteId.str);
          final info = DeviceInfo(
            type: DeviceType.ble,
            id: r.device.remoteId.str,
            name: name,
            subtitle: 'RSSI: ${r.rssi} dBm',
            address: r.device.remoteId.str,
            rssi: r.rssi,
            raw: r,
          );
          final idx = _devices.indexWhere((d) => d.id == info.id);
          if (idx >= 0) {
            _devices[idx] = info;
          } else {
            _devices.add(info);
            _deviceStream.add(info);
          }
        }
      });
    } catch (e) {
      _errorStream.add('Ошибка сканирования BLE: $e');
      _scanning = false;
      rethrow;
    }
  }

  /// Остановить сканирование.
  Future<void> stopScan() async {
    _scanning = false;
    await _scanSub?.cancel();
    _scanSub = null;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  /// Подключиться к BLE устройству и найти BLE Serial характеристику.
  ///
  /// Возвращает [BleSerialPort] или бросает исключение с понятным текстом.
  Future<BleSerialPort> connect(DeviceInfo info) async {
    final scanResult = info.raw as ScanResult;
    final device = scanResult.device;

    // Останавливаем скан перед подключением (проблема на некоторых телефонах)
    await stopScan();

    await device.connect(
      license: License.nonprofit,
      timeout: const Duration(seconds: 15),
    );
    await device.requestMtu(512).catchError((_) => 23);

    final services = await device.discoverServices();

    // 1) Ищем известные BLE Serial сервисы
    for (final service in services) {
      final sUuid = service.uuid.str.toLowerCase();
      if (BleSerialUuids.knownServices.contains(sUuid)) {
        final chars = service.characteristics;
        // Характеристика с write + notify (обычно одна для HM-10)
        BluetoothCharacteristic? tx;
        BluetoothCharacteristic? rx;
        for (final c in chars) {
          if (c.properties.write || c.properties.writeWithoutResponse) {
            tx ??= c;
          }
          if (c.properties.notify || c.properties.indicate) {
            rx ??= c;
          }
        }
        if (tx != null && rx != null) {
          await rx.setNotifyValue(true);
          return BleSerialPort(device, tx, rx);
        }
      }
    }

    // 2) Fallback: NUS по конкретным UUID
    for (final service in services) {
      if (service.uuid.str.toLowerCase() == BleSerialUuids.nusService) {
        BluetoothCharacteristic? tx;
        BluetoothCharacteristic? rx;
        for (final c in service.characteristics) {
          if (c.uuid.str.toLowerCase() == BleSerialUuids.nusTx) tx = c;
          if (c.uuid.str.toLowerCase() == BleSerialUuids.nusRx) rx = c;
        }
        if (tx != null && rx != null) {
          await rx.setNotifyValue(true);
          return BleSerialPort(device, tx, rx);
        }
      }
    }

    // 3) Общий поиск: любая характеристика с write и notify
    for (final service in services) {
      for (final c in service.characteristics) {
        final canWrite =
            c.properties.write || c.properties.writeWithoutResponse;
        final canNotify = c.properties.notify || c.properties.indicate;
        if (canWrite && canNotify) {
          await c.setNotifyValue(true);
          return BleSerialPort(device, c, c);
        }
      }
    }

    await device.disconnect();
    throw Exception(
      'На устройстве не найден BLE Serial сервис '
      '(FFE0/FFE1 или Nordic UART)',
    );
  }

  void dispose() {
    _scanSub?.cancel();
    _deviceStream.close();
    _errorStream.close();
    _stateStream.close();
  }
}

import 'dart:typed_data';

/// Тип транспортного интерфейса устройства.
enum DeviceType { ble, usb, classic }

/// Модель найденного устройства (BLE или USB).
class DeviceInfo {
  final DeviceType type;

  /// Уникальный идентификатор (BLE remoteId / USB deviceId).
  final String id;

  /// Отображаемое имя устройства.
  final String name;

  /// Дополнительная информация (производитель, чип, RSSI и т.п.).
  final String? subtitle;

  /// Уровень сигнала BLE/Classic (dBm), для USB — null.
  final int? rssi;

  /// Адрес Bluetooth устройства (для BLE — remoteId/MAC, для Classic — MAC).
  final String? address;

  /// Сырые данные (для BLE — ScanResult, для USB — UsbDevice).
  final Object? raw;

  const DeviceInfo({
    required this.type,
    required this.id,
    required this.name,
    this.subtitle,
    this.rssi,
    this.address,
    this.raw,
  });

  DeviceInfo copyWith({
    String? name,
    String? subtitle,
    int? rssi,
  }) {
    return DeviceInfo(
      type: type,
      id: id,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      rssi: rssi ?? this.rssi,
      raw: raw,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DeviceInfo && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);
}

/// Событие лога моста.
class BridgeLog {
  final DateTime time;
  final String message;
  final bool isError;

  BridgeLog(this.message, {this.isError = false}) : time = DateTime.now();

  String get timeLabel {
    final t = time;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

/// Пакет данных, прошедший через мост (для отображения в логе).
class DataPacket {
  final DateTime time;
  final Uint8List data;
  final bool fromDevice; // true: устройство -> TCP, false: TCP -> устройство

  DataPacket(this.data, {required this.fromDevice}) : time = DateTime.now();

  String get hex {
    final sb = StringBuffer();
    for (final b in data) {
      sb.write(b.toRadixString(16).padLeft(2, '0').toUpperCase());
      sb.write(' ');
    }
    return sb.toString().trim();
  }

  String get ascii {
    final sb = StringBuffer();
    for (final b in data) {
      sb.write(b >= 32 && b < 127 ? String.fromCharCode(b) : '.');
    }
    return sb.toString();
  }
}

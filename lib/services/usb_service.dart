import 'dart:async';
import 'dart:typed_data';

import 'package:usb_serial/usb_serial.dart';

import '../models/device_info.dart';
import 'settings_controller.dart';
import 'serial_port.dart';

/// Реализация [SerialPort] поверх USB UART (FTDI, CDC, CH340, CP210x и т.д.).
class UsbSerialPort implements SerialPort {
  final UsbPort _port;
  final String _label;

  UsbSerialPort(this._port, this._label);

  @override
  Stream<Uint8List> get inputStream =>
      _port.inputStream ?? const Stream.empty();

  @override
  Future<void> write(Uint8List data) async {
    await _port.write(data);
  }

  @override
  Future<void> close() async {
    try {
      await _port.close();
    } catch (_) {}
  }

  @override
  String get label => _label;
}

/// Сервис для работы с USB serial устройствами.
class UsbService {
  final SettingsController? settings;
  UsbService({this.settings});
  /// Список подключённых USB устройств.
  Future<List<DeviceInfo>> listDevices() async {
    final devices = await UsbSerial.listDevices();
    return devices.map((d) {
      final chip = _chipName(d);
      final product = (d.productName ?? '').trim();
      return DeviceInfo(
        type: DeviceType.usb,
        id: '${d.deviceId ?? d.vid}:${d.pid}',
        name: product.isNotEmpty ? product : chip,
        subtitle: chip,
        raw: d,
      );
    }).toList();
  }

  /// Подключиться к USB устройству.
  ///
  /// Возвращает [UsbSerialPort] или бросает исключение.
  Future<UsbSerialPort> connect(DeviceInfo info, {int baudRate = 115200}) async {
    final device = info.raw as UsbDevice;
    final port = await device.create();
    if (port == null) {
      throw Exception(settings?.s.usbPortCreateError ??
          'Не удалось создать порт для USB устройства');
    }

    final opened = await port.open();
    if (!opened) {
      throw Exception(settings?.s.usbPortOpenError ??
          'Не удалось открыть USB порт. '
              'Возможно, требуется разрешение на доступ к USB');
    }

    await port.setDTR(true);
    await port.setRTS(true);
    await port.setPortParameters(
      baudRate,
      UsbPort.DATABITS_8,
      UsbPort.STOPBITS_1,
      UsbPort.PARITY_NONE,
    );

    return UsbSerialPort(port, info.name);
  }

  /// Определить название чипа по VID/PID.
  String _chipName(UsbDevice d) {
    final vid = d.vid ?? 0;
    final pid = d.pid ?? 0;
    switch (vid) {
      case 0x0403: // FTDI
        switch (pid) {
          case 0x6001:
            return 'FTDI FT232R';
          case 0x6015:
            return 'FTDI FT231X';
          case 0x6010:
            return 'FTDI FT2232H';
          case 0x6011:
            return 'FTDI FT4232H';
          default:
            return 'FTDI (0x$pid)';
        }
      case 0x1A86: // WCH
        if (pid == 0x7523) return 'WCH CH340';
        if (pid == 0x5523) return 'WCH CH341A';
        return 'WCH CH34x (0x$pid)';
      case 0x10C4: // Silicon Labs
        if (pid == 0xEA60) return 'Silicon Labs CP2102';
        if (pid == 0xEA70) return 'Silicon Labs CP2105';
        return 'Silicon Labs CP210x (0x$pid)';
      case 0x067B: // Prolific
        if (pid == 0x2303) return 'Prolific PL2303';
        return 'Prolific (0x$pid)';
      case 0x2341: // Arduino
        return 'Arduino';
      case 0x16C0: // Teensy / CDC
        return 'Teensy / CDC';
      case 0x1366: // SEGGER
        return 'SEGGER J-Link';
      case 0x0483: // STMicroelectronics
        return 'STMicroelectronics VCP';
      default:
        return 'USB UART (VID:0x${vid.toRadixString(16)} PID:0x${pid.toRadixString(16)})';
    }
  }
}
import 'dart:async';
import 'dart:typed_data';

/// Единый интерфейс serial-порта (BLE Serial или USB UART),
/// чтобы мост работал одинаково для обоих типов устройств.
abstract class SerialPort {
  /// Поток входящих данных от устройства.
  Stream<Uint8List> get inputStream;

  /// Отправить данные в устройство.
  Future<void> write(Uint8List data);

  /// Закрыть порт и освободить ресурсы.
  Future<void> close();

  /// Имя/описание порта для логов.
  String get label;
}

/// Реализация, которая ничего не делает (порт не подключён).
class NullSerialPort implements SerialPort {
  @override
  Stream<Uint8List> get inputStream => const Stream.empty();

  @override
  Future<void> write(Uint8List data) async {}

  @override
  Future<void> close() async {}

  @override
  String get label => 'none';
}
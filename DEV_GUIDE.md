# DEV_GUIDE — Руководство для разработчиков

Документация для тех, кто хочет понять архитектуру, доработать или
расширить приложение **BLE/USB → TCP Bridge**.

---

## 1. Обзор

Приложение превращает Android-смартфон в мост между serial-устройством
(BLE Serial или USB UART) и локальным TCP-сервером.

```
┌──────────────┐    ┌─────────────────────┐    ┌──────────────────┐
│ BLE устройство│───▶│                     │───▶│  TCP клиент №1   │
│ (HM-10, NUS) │    │   BridgeController   │    └──────────────────┘
└──────────────┘    │  (мост данных  ⇄ )   │───▶│  TCP клиент №2   │
┌──────────────┐    │                     │    └──────────────────┘
│ USB UART     │───▶│  порт 0.0.0.0:8080  │
│ (CH340 и др.)│    └─────────────────────┘
└──────────────┘
```

Данные идут в **обе стороны**:
- устройство → все подключённые TCP-клиенты (broadcast);
- любой TCP-клиент → устройство.

---

## 2. Технологический стек

| Компонент | Пакет / технология | Назначение |
|---|---|---|
| BLE | [`flutter_blue_plus`](https://pub.dev/packages/flutter_blue_plus) ^2.3.14 | сканирование, подключение, GATT |
| Bluetooth Classic (SPP) | [`flutter_bluetooth_serial`](https://pub.dev/packages/flutter_bluetooth_serial) ^0.4.0 | RFCOMM: HC-05, HC-06 |
| USB Serial | [`usb_serial`](https://pub.dev/packages/usb_serial) ^0.5.2 | UART по USB (FTDI, CDC, CH340…) |
| Разрешения | [`permission_handler`](https://pub.dev/packages/permission_handler) ^11.x | runtime-разрешения Android |
| Состояние | [`provider`](https://pub.dev/packages/provider) ^6.x | `ChangeNotifier` + зависимости |
| Версия Android | [`device_info_plus`](https://pub.dev/packages/device_info_plus) ^13.x | определение API уровня |
| Локализация | `flutter_localizations` (SDK) | RU/EN |
| Хранение настроек | [`shared_preferences`](https://pub.dev/packages/shared_preferences) ^2.x | сохранение языка |
| TCP-сервер | `dart:io` (`ServerSocket`) | локальный TCP на 8080 |

Требования: Flutter ≥ 3.47, Dart ≥ 3.13, Android SDK 36, JDK 17,
minSdk 23, AGP 8.11.1, Gradle 8.14.

---

## 3. Структура проекта

```
lib/
├── main.dart                       # точка входа, тема, локализация, Provider
├── l10n/
│   └── app_strings.dart            # строки RU/EN (AppStrings)
├── models/
│   └── device_info.dart            # DeviceInfo (type, address), BridgeLog, DataPacket
├── services/
│   ├── serial_port.dart            # абстракция SerialPort (единый интерфейс)
│   ├── ble_service.dart            # BLE: скан, подключение, BLE Serial
│   ├── bt_classic_service.dart     # Classic SPP: discovery, RFCOMM
│   ├── usb_service.dart            # USB: список, подключение, ID чипов
│   ├── tcp_server_service.dart     # TCP-сервер (dart:io)
│   ├── settings_controller.dart    # язык (ChangeNotifier, shared_preferences)
│   └── bridge_controller.dart      # мост serial ⇄ TCP (ChangeNotifier)
├── screens/
│   ├── home_screen.dart            # нижняя навигация (3 вкладки)
│   ├── devices_screen.dart         # вкладка «Устройства»
│   ├── tcp_screen.dart             # вкладка «TCP сервер»
│   └── settings_screen.dart        # вкладка «Настройки»
└── widgets/
    ├── device_card.dart            # карточка: тип, RSSI, адрес
    └── status_banner.dart          # статус подключения

android/app/src/main/
├── AndroidManifest.xml             # BLE/USB/INTERNET-разрешения
└── res/xml/device_filter.xml       # USB VID/PID фильтр чипов UART
```

---

## 4. Ключевая абстракция: `SerialPort`

В [`lib/services/serial_port.dart`](lib/services/serial_port.dart) определён
единый интерфейс, благодаря которому мост не знает, работает ли он с BLE
или USB:

```dart
abstract class SerialPort {
  Stream<Uint8List> get inputStream; // данные от устройства
  Future<void> write(Uint8List data); // данные в устройство
  Future<void> close();
  String get label;
}
```

Реализации:
- [`BleSerialPort`](lib/services/ble_service.dart) — поверх GATT-характеристик;
- [`UsbSerialPort`](lib/services/usb_service.dart) — поверх `UsbPort` пакета `usb_serial`.

---

## 5. Сервисы

### 5.1 `BleService` — BLE

Отвечает за:
- сканирование (`startScan`, `stopScan`) с потоком `onDeviceFound`;
- запрос статуса адаптера (`adapterState`);
- **подключение и поиск BLE Serial** (`connect`).

Поддерживаемые BLE Serial:
1. **HM-10 / HC-08 / CC2541** — сервис `0000FFE0-…`, характеристика `0000FFE1-…`;
2. **Nordic UART Service (NUS)** — сервис `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`,
   TX `6E400002`, RX `6E400003`;
3. **Общий fallback** — любая характеристика с `write` + `notify`.

Запись в устройство разбивается по MTU:
```dart
final chunk = mtu - 3; // 3 байта — служебные BLE
```

**Фильтр «Только Serial-устройства»** — статический метод
`BleSerialUuids.isSerialCapable(ScanResult)`:
- проверяет `serviceUuids` рекламного пакета (FFE0 / NUS);
- проверяет имя устройства по списку ключевых слов
  (`hm-10`, `hc-08`, `jdy`, `bt05`, `uart`, `serial`, …).

> Новые модули BLE Serial добавляются в `serialNameHints` и/или `knownServices`.

### 5.2 `BtClassicService` — Bluetooth Classic (SPP)

- `FlutterBluetoothSerial.instance` — синглтон пакета
  `flutter_bluetooth_serial` (RFCOMM);
- `startDiscovery({filterSerialOnly})` — поиск устройств по имени + RSSI;
- `connect(info)` — `BluetoothConnection.toAddress(address)` → `BtClassicSerialPort`;
- `BtClassicSerialPort implements SerialPort` — тот же единый интерфейс моста.

**Фильтр Serial для Classic** — `BtClassicService.isSerialCapable(BluetoothDevice)`:
эвристика по имени (`hc-05`, `hc-06`, `uart`, `spp`, `jdy`, …), т.к.
библиотека не предоставляет `BluetoothClass` устройства.

> Для Classic-модуля с нестандартным именем при включённом фильтре
> добавьте его имя в `_serialNameHints`.

### 5.3 `UsbService` — USB UART

- `listDevices()` — список подключённых USB-устройств через `UsbSerial.listDevices()`;
- `connect(device, baudRate: 115200)` — открывает порт, задаёт параметры
  `8N1`, включает DTR/RTS;
- `_chipName(UsbDevice)` — определяет чип по **VID/PID**.

Поддерживаемые чипы (в `device_filter.xml` — те же VID/PID для автоуведомления):

| VID | Чип | PID |
|---|---|---|
| `0x1A86` | WCH CH340 / CH341 | `0x7523`, `0x5523` |
| `0x10C4` | Silicon Labs CP2102 / CP210x | `0xEA60`, `0xEA70` |
| `0x0403` | FTDI FT232R / FT231X / FT2232H / FT4232H | `0x6001`, `0x6015`, `0x6010`, `0x6011` |
| `0x067B` | Prolific PL2303 | `0x2303` |
| `0x2341` | Arduino | любое |
| `0x16C0` | Teensy / CDC | `0x0483` |
| `0x1366` | SEGGER J-Link | `0x0105` |
| `0x0483` | STMicroelectronics VCP | `0x5740` |

> Для нового чипа достаточно добавить ветку в `_chipName` и запись
> в `device_filter.xml` (десятичные VID/PID: `0x1A86` = 6790 и т.д.).

### 5.4 `TcpServerService` — TCP-сервер

- `ServerSocket.bind(InternetAddress.anyIPv4, port)` — слушает все интерфейсы;
- поддержка **нескольких клиентов** (`Set<Socket>`);
- `broadcast(Uint8List)` — рассылка всем клиентам;
- `onDataFromClients` — поток данных от клиентов (пишутся в устройство);
- `onEvent` — события подключения/отключения клиентов.

### 5.5 `BridgeController` — ядро моста

`ChangeNotifier`, связывает всё вместе:

```
TCP.onDataFromClients ──write──▶ SerialPort.write
SerialPort.inputStream ──broadcast──▶ TcpServer.broadcast
```

Также хранит:
- состояние подключения (`DeviceConnectionState`);
- журнал событий (`logs`) и пакеты данных (`packets`);
- счётчики байт (`bytesFromDevice` / `bytesToDevice`).

---

## 6. Поток данных (подключение устройства)

1. Вкладка «Устройства»: скан BLE или список USB.
2. Нажатие на устройство → `BridgeController.connect(device)`.
3. Для BLE: `BleService.connect()` → `device.connect()` → `discoverServices()`
   → поиск serial-характеристик → `setNotifyValue(true)`.
4. Для USB: `UsbService.connect()` → `port.open()` → параметры 115200 8N1.
5. `BridgeController` подписывается на `inputStream` устройства и пишет в
   `TcpServer.broadcast()`.
6. Данные от TCP-клиентов (`onDataFromClients`) пишутся в устройство.

---

## 7. Разрешения Android

Манифест ([`AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml)):

- **Android 12+**: `BLUETOOTH_SCAN` (с флагом `neverForLocation`),
  `BLUETOOTH_CONNECT`;
- **Android ≤ 11**: `BLUETOOTH`, `BLUETOOTH_ADMIN`,
  `ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION`;
- **сеть**: `INTERNET`, `ACCESS_NETWORK_STATE`;
- **USB**: `android.hardware.usb.host` (optional) + `device_filter.xml`.

Важно: `ACCESS_FINE_LOCATION` ограничен `maxSdkVersion="30"` — на Android 12+
разрешение на местоположение **не запрашивается и не требуется**
(проверка API-уровня в `_ensureBlePermissions()`).

---

## 8. Сборка и запуск

```bash
# 1) Зависимости
flutter pub get

# 2) Статическая проверка
flutter analyze

# 3) Сборка
flutter build apk --release    # или --debug

# 4) Установка на устройство (по USB)
flutter install
# или:
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

> **Важно.** Java/Gradle некорректно работает с не-ASCII путями
> (кириллица, пробелы). Если путь к проекту содержит такие символы
> (например, «Рабочий стол»), скопируйте проект в чистый путь
> (например, `~/project/ble-tcp-bridge`) перед сборкой.

Окружение (рекомендации):
- JDK 17 (Temurin);
- Android SDK 36 (`compileSdk 36`, `minSdk 23`, `targetSdk 35+`);
- Gradle 8.14, AGP 8.11.1 — версии уже зафиксированы в `settings.gradle`
  и `gradle-wrapper.properties`.

> **Патч `flutter_bluetooth_serial` 0.4.0 (обязателен при AGP 8+).**
> Пакет опубликован 5 лет назад и несовместим с современным AGP.
> Перед сборкой внесите правки в
> `~/.pub-cache/hosted/pub.dev/flutter_bluetooth_serial-0.4.0/android/build.gradle`:
> - замените `jcenter()` → `mavenCentral()` (оба места);
> - добавьте в блок `android { }`: `namespace 'io.github.edufolly.flutterbluetoothserial'`;
> - поднимите `compileSdkVersion 30` → `36`;
> - удалите `buildToolsVersion '30.0.3'`.
> Без этого сборка упадёт с ошибкой «Namespace not specified».

---

## 9. CI

[`.github/workflows/flutter-ci.yml`](.github/workflows/flutter-ci.yml):
- `flutter analyze` и `flutter test` на каждом push/PR;
- сборка debug APK и выгрузка артефакта.

---

## 10. Расширение приложения

| Задача | Что менять |
|---|---|
| Добавить BLE Serial модуль | `BleSerialUuids.knownServices` / `serialNameHints` |
| Добавить USB-чип | `UsbService._chipName` + `device_filter.xml` |
| Настроить скорость USB | параметр `baudRate` в `UsbService.connect` |
| Сменить порт TCP | поле порта на вкладке «TCP сервер» (по умолчанию 8080) |
| Автоподключение при старте | сохранять `device.id` и вызывать `connect` в `main.dart` |
| Фоновый режим | `flutter_foreground_task` (BLE) + служба для TCP |
| Несколько устройств сразу | несколько `SerialPort` + маршрутизация по `port` в `TcpServerService` |

---

## 11. Известные ограничения

- USB-хост требует OTG и поддержки на устройстве.
- TCP-сервер слушает `0.0.0.0` — данные доступны всем в локальной сети.
- `flutter_blue_plus` — для коммерческого использования требуется лицензия
  (передаётся параметром `License.nonprofit` / `License.commercial` в `device.connect()`).

---

## 12. Лицензия

Проект распространяется по [MIT](LICENSE).
Библиотека `flutter_blue_plus` имеет собственную лицензию
(некоммерческое использование — бесплатно).

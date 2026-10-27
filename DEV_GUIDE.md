# DEV_GUIDE — Developer Guide

Documentation for those who want to understand the architecture, modify or
extend the **BLE/USB → TCP Bridge** app.

---

## 1. Overview

The app turns an Android smartphone into a bridge between a serial device
(BLE Serial or USB UART) and a local TCP server.

```
┌──────────────┐    ┌─────────────────────┐    ┌──────────────────┐
│ BLE device   │───▶│                     │───▶│  TCP client #1   │
│ (HM-10, NUS) │    │   BridgeController  │    └──────────────────┘
└──────────────┘    │  (data bridge  ⇄ )  │───▶│  TCP client #2   │
┌──────────────┐    │                     │    └──────────────────┘
│ USB UART     │───▶│  port 0.0.0.0:8080  │
│ (CH340 etc.) │    └─────────────────────┘
└──────────────┘
```

Data flows in **both directions**:
- device → all connected TCP clients (broadcast);
- any TCP client → device.

---

## 2. Tech stack

| Component | Package / technology | Purpose |
|---|---|---|
| BLE | [`flutter_blue_plus`](https://pub.dev/packages/flutter_blue_plus) ^2.3.14 | scanning, connection, GATT |
| Bluetooth Classic (SPP) | [`flutter_bluetooth_serial`](https://pub.dev/packages/flutter_bluetooth_serial) ^0.4.0 | RFCOMM: HC-05, HC-06 |
| USB Serial | [`usb_serial`](https://pub.dev/packages/usb_serial) ^0.5.2 | UART over USB (FTDI, CDC, CH340…) |
| Permissions | [`permission_handler`](https://pub.dev/packages/permission_handler) ^11.x | Android runtime permissions |
| State | [`provider`](https://pub.dev/packages/provider) ^6.x | `ChangeNotifier` + dependencies |
| Android version | [`device_info_plus`](https://pub.dev/packages/device_info_plus) ^13.x | API level detection |
| Localization | `flutter_localizations` (SDK) | RU/EN |
| Settings storage | [`shared_preferences`](https://pub.dev/packages/shared_preferences) ^2.x | language persistence |
| TCP server | `dart:io` (`ServerSocket`) | local TCP on 8080 |

Requirements: Flutter ≥ 3.47, Dart ≥ 3.13, Android SDK 36, JDK 17,
minSdk 23, AGP 8.11.1, Gradle 8.14.

---

## 3. Project structure

```
lib/
├── main.dart                       # entry point, theme, localization, Provider
├── l10n/
│   └── app_strings.dart            # RU/EN strings (AppStrings)
├── models/
│   └── device_info.dart            # DeviceInfo (type, address), BridgeLog, DataPacket
├── services/
│   ├── serial_port.dart            # SerialPort abstraction (common interface)
│   ├── ble_service.dart            # BLE: scan, connect, BLE Serial
│   ├── bt_classic_service.dart     # Classic SPP: discovery, RFCOMM
│   ├── usb_service.dart            # USB: list, connect, chip IDs
│   ├── tcp_server_service.dart     # TCP server (dart:io)
│   ├── settings_controller.dart    # language (ChangeNotifier, shared_preferences)
│   └── bridge_controller.dart      # serial ⇄ TCP bridge (ChangeNotifier)
├── screens/
│   ├── home_screen.dart            # bottom navigation (3 tabs)
│   ├── devices_screen.dart         # "Devices" tab
│   ├── tcp_screen.dart             # "TCP server" tab
│   └── settings_screen.dart        # "Settings" tab
└── widgets/
    ├── device_card.dart            # card: type, RSSI, address
    └── status_banner.dart          # connection status

android/app/src/main/
├── AndroidManifest.xml             # BLE/USB/INTERNET permissions
└── res/xml/device_filter.xml       # USB VID/PID filter for UART chips
```

---

## 4. Key abstraction: `SerialPort`

In [`lib/services/serial_port.dart`](lib/services/serial_port.dart):

```dart
abstract class SerialPort {
  Stream<Uint8List> get inputStream;
  Future<void> write(Uint8List data);
  Future<void> close();
  String get label;
}
```

All three transports (BLE, Classic SPP, USB) implement this interface.
`BridgeController` works only with `SerialPort`, without knowing the concrete transport.

---

## 5. Services

### `BleService` (BLE)
- `ensureReady()` — checks BLE support, turns adapter on.
- `startScan({filterSerialOnly})` — starts scan via `FlutterBluePlus.startScan()`,
  filters results by serial capability.
- `connect(info)` — connects to the device, calls `discoverServices()`,
  searches for a BLE Serial characteristic (write + notify).
- `isSerialCapable(result)` — checks service UUIDs and name hints.

### `BtClassicService` (Bluetooth Classic SPP)
- `isEnabled()`, `listenAdapterState()`.
- `startDiscovery({filterSerialOnly})` — `FlutterBluetoothSerial.startDiscovery()`,
  filters by module name.
- `connect(info)` — `BluetoothConnection.toAddress(address)` → RFCOMM.
- `isSerialCapable(dev)` — heuristic by module name.

### `UsbService`
- `listDevices()` — returns a list of `DeviceInfo` with chip name by VID/PID.
- `connect(info)` — opens the port, sets 115200 8N1.

### `TcpServerService`
- `start(port)`, `stop()`.
- Streams: `onClientConnected`, `onDataFromClients`, `onEvent`.
- `broadcast(data)` — sends to all clients.

### `BridgeController`
- `connect(device)`, `disconnect()`.
- Subscribes to device `inputStream` → `tcpServer.broadcast()`.
- Subscribes to `onDataFromClients` → `port.write()`.
- Logs and counters.

### `SettingsController`
- `languageCode`, `setLanguage(code)`.
- Persists to `shared_preferences`.

---

## 6. Data flow

1. User selects a device on the "Devices" tab → `BridgeController.connect()`.
2. Controller calls the corresponding service `connect()` → gets a `SerialPort`.
3. Controller subscribes to `port.inputStream` and writes incoming data
   to `TcpServer.broadcast()`.
4. Controller subscribes to `tcpServer.onDataFromClients` and writes data to `port`.
5. On the "TCP server" tab the user starts the server → `TcpServerService.start()`.

---

## 7. Android permissions

Manifest ([`AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml)):

- **Android 12+**: `BLUETOOTH_SCAN` (with `neverForLocation` flag),
  `BLUETOOTH_CONNECT`;
- **Android ≤ 11**: `BLUETOOTH`, `BLUETOOTH_ADMIN`,
  `ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION`;
- **network**: `INTERNET`, `ACCESS_NETWORK_STATE`;
- **USB**: `android.hardware.usb.host` (optional) + `device_filter.xml`.

Important: `ACCESS_FINE_LOCATION` is limited by `maxSdkVersion="30"` — on Android 12+
location permission is **not requested and not required**
(API level check in `_ensureBlePermissions()`).

---

## 8. Build and run

```bash
# 1) Dependencies
flutter pub get

# 2) Static analysis
flutter analyze

# 3) Build
flutter build apk --release    # or --debug

# 4) Install on a device (over USB)
flutter install
# or:
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

> **Important.** Java/Gradle does not work correctly with non-ASCII paths
> (Cyrillic, spaces). If the project path contains such characters
> (for example, "Рабочий стол"), copy the project to a clean path
> (for example, `~/project/ble-tcp-bridge`) before building.

Environment (recommendations):
- JDK 17 (Temurin);
- Android SDK 36 (`compileSdk 36`, `minSdk 23`, `targetSdk 35+`);
- Gradle 8.14, AGP 8.11.1 — versions are already pinned in `settings.gradle`
  and `gradle-wrapper.properties`.

> **Patch `flutter_bluetooth_serial` 0.4.0 (required for AGP 8+).**
> The package was published 5 years ago and is incompatible with modern AGP.
> Before building, apply edits to
> `~/.pub-cache/hosted/pub.dev/flutter_bluetooth_serial-0.4.0/android/build.gradle`:
> - replace `jcenter()` → `mavenCentral()` (both places);
> - add to the `android { }` block: `namespace 'io.github.edufolly.flutterbluetoothserial'`;
> - raise `compileSdkVersion 30` → `36`;
> - remove `buildToolsVersion '30.0.3'`.
> Without this the build fails with "Namespace not specified".

---

## 9. CI

[`.github/workflows/flutter-ci.yml`](.github/workflows/flutter-ci.yml):
- `flutter analyze` and `flutter test` on every push/PR;
- debug APK build and artifact upload.

---

## 10. Extending the app

| Task | What to change |
|---|---|
| Add a BLE Serial module | `BleSerialUuids.knownServices` / `serialNameHints` |
| Add a USB chip | `UsbService._chipName` + `device_filter.xml` |
| Configure USB baud rate | `baudRate` parameter in `UsbService.connect` |
| Change TCP port | port field on the "TCP server" tab (default 8080) |
| Auto-connect on startup | store `device.id` and call `connect` in `main.dart` |
| Background mode | `flutter_foreground_task` (BLE) + service for TCP |
| Multiple devices at once | multiple `SerialPort` + routing by `port` in `TcpServerService` |

---

## 11. Known limitations

- USB host requires OTG and device support.
- TCP server listens on `0.0.0.0` — data is available to everyone on the local network.
- `flutter_blue_plus` — a license is required for commercial use
  (passed via the `License.nonprofit` / `License.commercial` parameter in `device.connect()`).

---

## 12. License

Project is distributed under [MIT](LICENSE).
The `flutter_blue_plus` library has its own license
(non-commercial use is free).

# BLE/USB → TCP Bridge (Android, Flutter)

> 📖 Подробная документация для разработчиков: **[DEV_GUIDE.md](DEV_GUIDE.md)**
> (архитектура, сервисы, расширение функциональности).

Приложение для Android, которое превращает смартфон в мост между
**serial-устройствами** (BLE Serial или USB UART) и **локальным TCP-сервером**
на порту **8080**.

## Возможности

### 📡 Вкладка «Устройства»
- **BLE-сканирование** — поиск BLE устройств рядом (RSSI, имя).
- **Фильтр «Только Serial-устройства»** — переключатель, который отсеивает
  устройства, непригодные для serial-обмена: остаются только BLE Serial
  модули (имена HM-10, HC-08, JDY, AT-09 и т.п.) и устройства с сервисами
  `FFE0`/Nordic UART в рекламном пакете.
- **BLE Serial** — поддержка популярных BLE Serial модулей:
  - HM-10 / HC-08 / CC2541 (сервис `FFE0`, характеристика `FFE1`);
  - Nordic UART Service (NUS) — `6E400001/2/3`;
  - автоматический поиск любой характеристики с write + notify.
- **USB UART** — поддержка всех распространённых чипов UART/TTL:
  - WCH **CH340 / CH341**;
  - Silicon Labs **CP2102 / CP210x**;
  - FTDI **FT232R / FT231X / FT2232H / FT4232H**;
  - Prolific **PL2303**;
  - Arduino, Teensy, STM32 VCP, SEGGER J-Link и другие CDC-устройства.
- Подключение одним нажатием, индикация статуса.

### 🌐 Вкладка «TCP сервер»
- Запуск/остановка локального TCP-сервера на порту **8080** (порт настраивается).
- Поддержка **нескольких TCP-клиентов** одновременно.
- **Проброс данных в обе стороны**:
  - устройство → все TCP-клиенты (broadcast);
  - любой TCP-клиент → устройство.
- Счётчики переданных байт, журнал событий и очистка лога.

## Стек

| Компонент | Пакет |
|---|---|
| BLE | [`flutter_blue_plus`](https://pub.dev/packages/flutter_blue_plus) |
| USB Serial | [`usb_serial`](https://pub.dev/packages/usb_serial) |
| Разрешения | [`permission_handler`](https://pub.dev/packages/permission_handler) |
| Состояние | [`provider`](https://pub.dev/packages/provider) |
| TCP-сервер | `dart:io` (`ServerSocket`) |

## Сборка

```bash
flutter pub get
flutter build apk --debug   # или --release
```

APK появится в `build/app/outputs/flutter-apk/`.

### Требования
- Flutter SDK 3.47+ (Dart ≥ 3.13)
- JDK 17 (Temurin/OpenJDK)
- Android SDK: `compileSdk 36`, `minSdk 23`, `targetSdk 35+`
- Gradle 8.14 / AGP 8.11.1 (версии уже заданы в проекте)
- Для запуска на устройстве: Android 6.0+ (BLE), поддержка USB Host (OTG)
- Примечание: путь проекта не должен содержать кириллицу/пробелы —
  Java/Gradle некорректно работает с не-ASCII путями (`flutter build` из пути
  с пробелами невозможен).

## Разрешения Android

- `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT` (Android 12+)
- `BLUETOOTH`, `BLUETOOTH_ADMIN`, `ACCESS_FINE_LOCATION` (Android ≤ 11)
- `INTERNET`, `ACCESS_NETWORK_STATE` (TCP-сервер)
- USB Host + `device_filter.xml` (CH340, CP210x, FTDI, PL2303, Arduino и др.)

## Как использовать

1. Установите приложение на Android-смартфон.
2. **Вкладка «Устройства»**:
   - BLE: нажмите «Сканировать», выберите устройство.
   - USB: подключите адаптер через OTG, нажмите «Обновить», выберите устройство.
3. **Вкладка «TCP сервер»**: нажмите «Запустить сервер».
4. Подключайтесь с любого устройства в локальной сети:
   ```bash
   # пример: чтение данных с serial-устройства
   nc <IP-смартфона> 8080
   ```
   IP смартфона можно узнать в настройках Wi-Fi.

## Структура проекта

```
lib/
├── main.dart                     # точка входа, тема, Provider
├── models/
│   └── device_info.dart          # DeviceInfo, BridgeLog, DataPacket
├── services/
│   ├── serial_port.dart          # абстракция SerialPort
│   ├── ble_service.dart           # BLE скан/подключение/BLE Serial
│   ├── usb_service.dart           # USB UART (CH340, CP210x, FTDI...)
│   ├── tcp_server_service.dart    # TCP-сервер (dart:io)
│   └── bridge_controller.dart     # связка serial <-> TCP
├── screens/
│   ├── home_screen.dart           # нижняя навигация
│   ├── devices_screen.dart        # вкладка «Устройства»
│   └── tcp_screen.dart            # вкладка «TCP сервер»
└── widgets/
    ├── device_card.dart
    └── status_banner.dart
```

## Примечания

- BLE Serial работает только с BLE-устройствами (не Bluetooth Classic —
  HC-05/HC-06 не поддерживаются).
- Для USB нужен кабель OTG и поддержка USB Host на устройстве.
- TCP-сервер слушает `0.0.0.0` — доступен всем устройствам в той же сети.
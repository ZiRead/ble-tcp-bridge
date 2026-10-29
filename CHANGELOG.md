# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.3.1] — 2026-10-27

### Added
- **Terminal settings**: Data/Stop bits, Parity, Flow control, Line ending,
  Auto scroll, RX/TX display mode (ASCII/HEX).
- **USB baud rate**: extended list up to 921600 + manual input.
- **Export terminal log**: system save dialog to choose destination.
- **"Terminal settings" button** in Settings and quick button in Terminal tab.

### Changed
- Removed 5/6 data bits and 1.5 stop bit options (non-standard).
- RX/TX display mode uses dropdowns like other settings.

### Fixed
- Dropdown value safety (no invalid selections).
- (Other minor fixes.)

## [1.3.0] — 2026-10-27

### Added
- **"Terminal" tab**: direct serial access with customizable view (font size,
  text/background colors) and command input.
- **Command history**: navigate previous commands with arrows; selected command
  is highlighted.
- **Status banner** on the Terminal tab (connection status).

### Changed
- Serial port streams are broadcast, allowing terminal and bridge to receive data
  simultaneously.

### Fixed
- Terminal now receives device responses (broadcast streams).
- Command history highlighting selects only the chosen occurrence.

## [1.2.5] — 2026-10-27

### Fixed
- **Notification language**: notification text now updates immediately when the
  language is changed (also after dismiss/reappear).
- **Notification persists after swipe**: no longer stays visible when the server
  is stopped.

## [1.2.4] — 2026-10-27

### Added
- **Background mode for TCP server**: foreground service with a persistent
  notification (short summary + expanded details).
- **Notification auto-restore**: reappears if dismissed while the server runs.
- **Open app from notification**: tapping the notification opens the app.
- **"Request permissions" button** on the "Settings" tab (style like "About").

### Changed
- Notification shows connected device name and address in expanded view.
- Foreground service stops cleanly when the app is removed from recents.

### Fixed
- Notification no longer appears when the TCP server is stopped.
- Stale notification/service is cleared on app start.

## [1.2.3] — 2026-10-27

### Added
- **Localized log messages**: bridge, TCP server, BLE, Bluetooth Classic and USB
  messages are now shown in the selected UI language (RU/EN).
- **Non-Serial devices**: shown as disabled (cannot be connected) when the new
  setting is enabled.
- **Setting to disable connection to non-Serial devices** (on the "Settings" tab).

### Changed
- **TCP server address**: displays all local IP addresses of the smartphone
  (one per line), with `localhost` always last.
- **Settings UI**: USB baud rate and the non-Serial toggle are placed before
  the "About" button.

### Fixed
- **Bluetooth device names**: name is taken from the device (trimmed); address is
  used as fallback. Plugin patched to use `EXTRA_NAME`.
- **Serial-only filter description**: updated to mention both BLE Serial and
  Bluetooth Classic.

## [1.2.2] — 2026-10-27

### Fixed
- **TCP server address display**: shows the real local IP address of the
  smartphone (Wi-Fi/LAN) instead of `0.0.0.0`, plus `localhost` on a second line.

## [1.2.1] — 2026-10-27

### Added
- **USB baud rate setting**: selectable baud rate (9600, 19200, 38400, 57600,
  115200) on the "Settings" tab, applied when connecting a USB device.

### Changed
- Removed the non-functional Bluetooth baud rate setting (Bluetooth Classic/BLE
  do not use a configurable baud rate).

## [1.2.0] — 2026-10-27

### Added
- **"About" button** on the "Settings" tab: a dialog with app description,
  a link to the GitHub repository and license information (MIT).
  The dialog is not full-screen; it can be closed with a button/cross or by
  tapping outside.

### Changed
- "Serial devices only" filter: the description shown when the filter is active
  now covers both BLE Serial and Bluetooth Classic (HC-05/HC-06, etc.).

### Fixed
- **Bluetooth device names display**: the name is taken from the device itself
  (trimmed), and its address (MAC/remoteId) is used when no name is available.
  The `flutter_bluetooth_serial` plugin is patched to use `EXTRA_NAME` from the
  discovery intent.
- Documentation translated into English.

## [1.1.1] — 2026-10-27

### Fixed
- **Bluetooth Classic search on Android 12+**: fixed the error
  `PlatformException(no_permissions, discovering other devices requires location
  access permission, null, null)` during scanning. Location permission is now
  requested on all Android versions for Classic device discovery (the
  `flutter_bluetooth_serial` plugin); `ACCESS_FINE_LOCATION` /
  `ACCESS_COARSE_LOCATION` are declared in the manifest without `maxSdkVersion`.
  BLE scanning still uses `BLUETOOTH_SCAN` with the `neverForLocation` flag and
  does not require location on Android 12+.

## [1.1.0] — 2026-10-26

### Added
- **Bluetooth Classic (SPP) support** — connection of HC-05 / HC-06 modules
  and similar (package `flutter_bluetooth_serial`):
  - common Bluetooth search: one "Scan" button finds BLE and Classic devices
    simultaneously;
  - BLE and Classic devices are shown in the common "Bluetooth" section with a
    type label (`BLE` / `Classic`);
  - Bluetooth device address (MAC) is shown for each device next to RSSI.
- **English language** — full UI localization (RU/EN).
- **"Settings" tab** — language selection persisted between launches.
- **"Serial devices only" filter** now works for both BLE
  (by FFE0/NUS services and name) and Bluetooth Classic (by module name).

### Changed
- Device card: address moved to a separate line
  (monospace font), device type shown in the subtitle.

### Technical note
- `flutter_bluetooth_serial` 0.4.0 requires a local patch to build under
  AGP 8+: `namespace` added, `mavenCentral` instead of `jcenter`,
  `compileSdkVersion 36` (details in `DEV_GUIDE.md`).

## [1.0.0] — 2026-10-26

### Added
- **"Devices" tab**:
  - BLE scanning with signal level (RSSI) and permission flow for Android 6–16;
  - connection to **BLE Serial** devices: HM-10 / HC-08 / CC2541 (`FFE0`/`FFE1`),
    Nordic UART Service (`6E400001-3`), automatic search for a write+notify characteristic;
  - connection to **USB UART** (via OTG): WCH CH340/CH341, Silicon Labs CP210x,
    FTDI FT232R/FT231X/FT2232H/FT4232H, Prolific PL2303, Arduino, Teensy,
    STM32 VCP, SEGGER J-Link — with auto-detection of the chip by VID/PID;
  - **"Serial devices only"** toggle — filter that excludes devices unsuitable
    for serial exchange;
  - device disconnect button.
- **"TCP server" tab**:
  - local TCP server on `0.0.0.0:8080` (configurable port);
  - bidirectional data forwarding: device → broadcast to all clients,
    client → device;
  - support for multiple TCP clients simultaneously;
  - byte counters and event log.
- Android configuration: BLE permissions (including `neverForLocation`),
  INTERNET, USB Host + `device_filter.xml` with UART chip list.
- Dark and light themes (Material 3).

### Fixed
- Location permission is no longer requested on Android 12+
  (BLE scan uses `BLUETOOTH_SCAN` with `neverForLocation` flag).
- App icon: symmetric arrows centered.

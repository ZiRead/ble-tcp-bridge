/// Локализация приложения: русский и английский.
///
/// Использование: `context.watch<SettingsController>().s` возвращает
/// [AppStrings] для выбранного языка.
class AppStrings {
  final bool isRu;
  const AppStrings(this.isRu);

  static const ru = AppStrings(true);
  static const en = AppStrings(false);

  // ===== Общее / навигация =====
  String get appTitle => 'BLE/USB TCP Bridge';
  String get tabDevices => isRu ? 'Устройства' : 'Devices';
  String get tabTcp => isRu ? 'TCP сервер' : 'TCP Server';
  String get tabSettings => isRu ? 'Настройки' : 'Settings';

  // ===== Статус подключения =====
  String get statusConnected => isRu ? 'Подключено' : 'Connected';
  String get statusConnecting => isRu ? 'Подключение...' : 'Connecting...';
  String get statusDisconnected =>
      isRu ? 'Устройство не подключено' : 'No device connected';
  String get btnDisconnect =>
      isRu ? 'Отключить устройство' : 'Disconnect device';

  // ===== Вкладка «Устройства» =====
  String get secBt => isRu ? 'Bluetooth' : 'Bluetooth';
  String get secUsb => isRu ? 'USB устройства' : 'USB devices';

  String get btnScan => isRu ? 'Сканировать' : 'Scan';
  String get btnStop => isRu ? 'Стоп' : 'Stop';
  String get btnRefresh => isRu ? 'Обновить' : 'Refresh';
  String get filterTitle =>
      isRu ? 'Только Serial-устройства' : 'Serial-only devices';
  String get filterSubtitle => isRu
      ? 'Показывать только Serial-устройства (BLE и Classic SPP)'
      : 'Show only Serial-capable devices (BLE & Classic SPP)';

  String get emptyBle => isRu
      ? 'Нажмите «Сканировать», чтобы найти BLE устройства.\n'
          'Поддерживаются BLE Serial (HM-10, HC-08, NUS).'
      : 'Press "Scan" to find BLE devices.\n'
          'BLE Serial supported (HM-10, HC-08, NUS).';
  String get emptyBleFiltered => isRu
      ? 'Нажмите «Сканировать».\n'
          'Фильтр «Только Serial» активен — будут показаны лишь '
          'устройства BLE Serial (HM-10, HC-08, Nordic UART и т.п.).'
      : 'Press "Scan".\n'
          '"Serial-only" filter is active — only BLE Serial devices '
          'will be shown (HM-10, HC-08, Nordic UART, etc.).';
  String get emptyUsb => isRu
      ? 'Подключите USB UART адаптер (CH340, CP2102, FTDI, '
          'PL2303 и др.) через OTG-кабель.'
      : 'Connect a USB UART adapter (CH340, CP2102, FTDI, '
          'PL2303, etc.) via an OTG cable.';
  String get emptyBt => isRu
      ? 'Нажмите «Сканировать», чтобы найти Bluetooth устройства.\n'
          'Поддерживаются BLE Serial (HM-10, HC-08, NUS) '
          'и Bluetooth Classic SPP (HC-05, HC-06).'
      : 'Press "Scan" to discover Bluetooth devices.\n'
          'Supported: BLE Serial (HM-10, HC-08, NUS) '
          'and Bluetooth Classic SPP (HC-05, HC-06).';

  String get bleDeviceFallback => isRu ? 'BLE устройство' : 'BLE device';
  String get usbDeviceLabel => isRu ? 'USB устройство' : 'USB device';
  String get classicDeviceLabel =>
      isRu ? 'Classic устройство' : 'Classic device';

  String rssi(int rssi) => '$rssi dBm';
  String rssiWithAddress(int rssi, String address) =>
      'RSSI: $rssi dBm • $address';

  String get errorBluetoothOff => isRu
      ? 'Bluetooth выключен. Включите Bluetooth'
      : 'Bluetooth is off. Please enable Bluetooth';
  String get errorBleScan => isRu
      ? 'Нет разрешения на сканирование BLE. '
          'Выдайте его: Настройки → Приложения → BLE/USB TCP Bridge → Разрешения'
      : 'No Bluetooth scan permission. Grant it in: '
          'Settings → Apps → BLE/USB TCP Bridge → Permissions';
  String get errorBleConnect => isRu
      ? 'Нет разрешения на подключение BLE'
      : 'No Bluetooth connect permission';
  String get errorLocation => isRu
      ? 'Для поиска Bluetooth (Classic) нужно разрешение на местоположение'
      : 'Location permission is required for Bluetooth (Classic) discovery';
  String get errorUsbList =>
      isRu ? 'Ошибка чтения USB устройств' : 'Failed to list USB devices';
  String connectFailed(String name) => isRu
      ? 'Не удалось подключиться к "$name"'
      : 'Failed to connect to "$name"';

  // ===== Вкладка «TCP сервер» =====
  String get serverRunning => isRu ? 'Сервер запущен' : 'Server running';
  String get serverStopped => isRu ? 'Сервер остановлен' : 'Server stopped';
  String clients(int n) =>
      isRu ? '$n клиент(ов)' : (n == 1 ? '1 client' : '$n clients');
  String get labelPort => isRu ? 'Порт:' : 'Port:';
  String get labelAddress => isRu ? 'Адрес:' : 'Address:';
  String get btnStartServer => isRu ? 'Запустить сервер' : 'Start server';
  String get btnStopServer => isRu ? 'Остановить сервер' : 'Stop server';
  String get tipConnectDevice => isRu
      ? 'Совет: подключите устройство на вкладке «Устройства», '
          'чтобы данные передавались в TCP.'
      : 'Tip: connect a device on the "Devices" tab so data '
          'is forwarded to TCP.';
  String get statFromDevice => isRu ? 'Из устройства' : 'From device';
  String get statToDevice => isRu ? 'В устройство' : 'To device';
  String get logTitle => isRu ? 'Лог' : 'Log';
  String get btnClear => isRu ? 'Очистить' : 'Clear';
  String get logEmpty => isRu
      ? 'Лог пуст. Запустите сервер и подключите устройство.'
      : 'Log is empty. Start the server and connect a device.';
  String get invalidPort =>
      isRu ? 'Некорректный порт (1–65535)' : 'Invalid port (1–65535)';

  // ===== Вкладка «Настройки» =====
  String get settingsLanguage => isRu ? 'Язык / Language' : 'Язык / Language';
  String get settingsLangRu => 'Русский';
  String get settingsLangEn => 'English';
  String get settingsHint => isRu
      ? 'Изменение языка применяется сразу'
      : 'Language change applies immediately';
}

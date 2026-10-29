import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';

/// Управление настройками приложения: язык, скорости (baud rate).
class SettingsController extends ChangeNotifier {
  static const _prefKey = 'app_language';
  static const _prefUsbBaud = 'usb_baud_rate';
  static const _prefDisableNonSerial = 'disable_non_serial';
  static const _prefTermFontSize = 'terminal_font_size';
  static const _prefTermTextColor = 'terminal_text_color';
  static const _prefTermBgColor = 'terminal_bg_color';
  static const _prefTermDataBits = 'terminal_data_bits';
  static const _prefTermStopBits = 'terminal_stop_bits';
  static const _prefTermParity = 'terminal_parity';
  static const _prefTermFlow = 'terminal_flow_control';
  static const _prefTermLineEnding = 'terminal_line_ending';
  static const _prefTermAutoScroll = 'terminal_auto_scroll';
  static const _prefTermRxHex = 'terminal_rx_hex';
  static const _prefTermTxHex = 'terminal_tx_hex';
  static const _prefTermNewLine = 'terminal_new_line_on_receive';

  Locale _locale = const Locale('ru');
  Locale get locale => _locale;

  /// Строки для выбранного языка.
  AppStrings get s =>
      _locale.languageCode == 'en' ? AppStrings.en : AppStrings.ru;

  String get languageCode => _locale.languageCode;

  int _usbBaudRate = 115200;
  int get usbBaudRate => _usbBaudRate;

  bool _disableNonSerialDevices = true;
  bool get disableNonSerialDevices => _disableNonSerialDevices;

  double _terminalFontSize = 14;
  double get terminalFontSize => _terminalFontSize;

  int _terminalTextColor = 0;
  int get terminalTextColor => _terminalTextColor;

  int _terminalBgColor = 0;
  int get terminalBgColor => _terminalBgColor;

  int _terminalDataBits = 8;
  int get terminalDataBits => _terminalDataBits;

  int _terminalStopBits = 1; // STOPBITS_1
  int get terminalStopBits => _terminalStopBits;

  int _terminalParity = 0; // PARITY_NONE
  int get terminalParity => _terminalParity;

  int _terminalFlowControl = 0; // FLOW_CONTROL_OFF
  int get terminalFlowControl => _terminalFlowControl;

  String _terminalLineEnding = '\n';
  String get terminalLineEnding => _terminalLineEnding;

  bool _terminalAutoScroll = true;
  bool get terminalAutoScroll => _terminalAutoScroll;

  bool _terminalNewLineOnReceive = true;
  bool get terminalNewLineOnReceive => _terminalNewLineOnReceive;

  bool _terminalRxHex = false;
  bool get terminalRxHex => _terminalRxHex;

  bool _terminalTxHex = false;
  bool get terminalTxHex => _terminalTxHex;

  /// Загрузить сохранённые настройки из shared_preferences.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefKey) ?? 'ru';
      _locale = (code == 'en') ? const Locale('en') : const Locale('ru');
      _usbBaudRate = prefs.getInt(_prefUsbBaud) ?? 115200;
      const bauds = [9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600];
      if (!bauds.contains(_usbBaudRate)) _usbBaudRate = 115200;
      _disableNonSerialDevices =
          prefs.getBool(_prefDisableNonSerial) ?? true;
      _terminalFontSize = prefs.getDouble(_prefTermFontSize) ?? 14;
      if (![10.0, 12.0, 14.0, 16.0, 18.0, 20.0].contains(_terminalFontSize)) {
        _terminalFontSize = 14;
      }
      _terminalTextColor = prefs.getInt(_prefTermTextColor) ?? 0;
      if (_terminalTextColor < 0 || _terminalTextColor > 4) _terminalTextColor = 0;
      _terminalBgColor = prefs.getInt(_prefTermBgColor) ?? 0;
      if (_terminalBgColor < 0 || _terminalBgColor > 3) _terminalBgColor = 0;
      _terminalDataBits = prefs.getInt(_prefTermDataBits) ?? 8;
      if (![7, 8].contains(_terminalDataBits)) _terminalDataBits = 8;
      _terminalStopBits = prefs.getInt(_prefTermStopBits) ?? 1;
      if (![1, 2].contains(_terminalStopBits)) _terminalStopBits = 1;
      _terminalParity = prefs.getInt(_prefTermParity) ?? 0;
      if (_terminalParity < 0 || _terminalParity > 2) _terminalParity = 0;
      _terminalFlowControl = prefs.getInt(_prefTermFlow) ?? 0;
      if (_terminalFlowControl < 0 || _terminalFlowControl > 3) _terminalFlowControl = 0;
      _terminalLineEnding = prefs.getString(_prefTermLineEnding) ?? '\n';
      if (!['\n', '\r', '\r\n'].contains(_terminalLineEnding)) _terminalLineEnding = '\n';
      _terminalAutoScroll = prefs.getBool(_prefTermAutoScroll) ?? true;
      _terminalRxHex = prefs.getBool(_prefTermRxHex) ?? false;
      _terminalTxHex = prefs.getBool(_prefTermTxHex) ?? false;
      _terminalNewLineOnReceive = prefs.getBool(_prefTermNewLine) ?? true;
      notifyListeners();
    } catch (_) {}
  }

  /// Установить язык и сохранить выбор.
  Future<void> setLanguage(String code) async {
    _locale = (code == 'en') ? const Locale('en') : const Locale('ru');
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, _locale.languageCode);
    } catch (_) {}
  }

  /// Установить скорость (baud rate) для USB и сохранить выбор.
  Future<void> setUsbBaudRate(int baud) async {
    _usbBaudRate = baud;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefUsbBaud, baud);
    } catch (_) {}
  }

  /// Включить/выключить блокировку подключения к не-Serial устройствам.
  Future<void> setDisableNonSerialDevices(bool value) async {
    _disableNonSerialDevices = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefDisableNonSerial, value);
    } catch (_) {}
  }

  Future<void> setTerminalFontSize(double value) async {
    _terminalFontSize = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefTermFontSize, value);
    } catch (_) {}
  }

  Future<void> setTerminalTextColor(int value) async {
    _terminalTextColor = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefTermTextColor, value);
    } catch (_) {}
  }

  Future<void> setTerminalBgColor(int value) async {
    _terminalBgColor = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefTermBgColor, value);
    } catch (_) {}
  }

  Future<void> setTerminalDataBits(int value) async {
    _terminalDataBits = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefTermDataBits, value);
    } catch (_) {}
  }

  Future<void> setTerminalStopBits(int value) async {
    _terminalStopBits = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefTermStopBits, value);
    } catch (_) {}
  }

  Future<void> setTerminalParity(int value) async {
    _terminalParity = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefTermParity, value);
    } catch (_) {}
  }

  Future<void> setTerminalFlowControl(int value) async {
    _terminalFlowControl = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefTermFlow, value);
    } catch (_) {}
  }

  Future<void> setTerminalLineEnding(String value) async {
    _terminalLineEnding = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefTermLineEnding, value);
    } catch (_) {}
  }

  Future<void> setTerminalAutoScroll(bool value) async {
    _terminalAutoScroll = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefTermAutoScroll, value);
    } catch (_) {}
  }

  bool _terminalSettingsRequested = false;
  bool get terminalSettingsRequested => _terminalSettingsRequested;

  void requestTerminalSettings() {
    _terminalSettingsRequested = true;
    notifyListeners();
  }

  void clearTerminalSettingsRequest() {
    _terminalSettingsRequested = false;
  }

  Future<void> setTerminalRxHex(bool value) async {
    _terminalRxHex = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefTermRxHex, value);
    } catch (_) {}
  }

  Future<void> setTerminalTxHex(bool value) async {
    _terminalTxHex = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefTermTxHex, value);
    } catch (_) {}
  }

  Future<void> setTerminalNewLineOnReceive(bool value) async {
    _terminalNewLineOnReceive = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefTermNewLine, value);
    } catch (_) {}
  }
}

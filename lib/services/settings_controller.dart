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

  /// Загрузить сохранённые настройки из shared_preferences.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefKey) ?? 'ru';
      _locale = (code == 'en') ? const Locale('en') : const Locale('ru');
      _usbBaudRate = prefs.getInt(_prefUsbBaud) ?? 115200;
      _disableNonSerialDevices =
          prefs.getBool(_prefDisableNonSerial) ?? true;
      _terminalFontSize = prefs.getDouble(_prefTermFontSize) ?? 14;
      _terminalTextColor = prefs.getInt(_prefTermTextColor) ?? 0;
      _terminalBgColor = prefs.getInt(_prefTermBgColor) ?? 0;
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
}

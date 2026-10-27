import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';

/// Управление настройками приложения: язык, скорости (baud rate).
class SettingsController extends ChangeNotifier {
  static const _prefKey = 'app_language';
  static const _prefUsbBaud = 'usb_baud_rate';

  Locale _locale = const Locale('ru');
  Locale get locale => _locale;

  /// Строки для выбранного языка.
  AppStrings get s =>
      _locale.languageCode == 'en' ? AppStrings.en : AppStrings.ru;

  String get languageCode => _locale.languageCode;

  int _usbBaudRate = 115200;
  int get usbBaudRate => _usbBaudRate;

  /// Загрузить сохранённые настройки из shared_preferences.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefKey) ?? 'ru';
      _locale = (code == 'en') ? const Locale('en') : const Locale('ru');
      _usbBaudRate = prefs.getInt(_prefUsbBaud) ?? 115200;
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
}

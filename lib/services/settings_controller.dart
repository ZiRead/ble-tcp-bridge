import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';

/// Управление настройками приложения: выбранный язык.
class SettingsController extends ChangeNotifier {
  static const _prefKey = 'app_language';

  Locale _locale = const Locale('ru');
  Locale get locale => _locale;

  /// Строки для выбранного языка.
  AppStrings get s =>
      _locale.languageCode == 'en' ? AppStrings.en : AppStrings.ru;

  String get languageCode => _locale.languageCode;

  /// Загрузить сохранённый язык из shared_preferences.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefKey) ?? 'ru';
      _locale = (code == 'en') ? const Locale('en') : const Locale('ru');
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
}

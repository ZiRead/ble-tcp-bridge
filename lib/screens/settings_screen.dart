import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/settings_controller.dart';

/// Вкладка «Настройки»: выбор языка приложения.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final s = settings.s;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.tabSettings),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            s.settingsLanguage,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'ru',
                label: Text('Русский'),
                icon: Icon(Icons.language),
              ),
              ButtonSegment(
                value: 'en',
                label: Text('English'),
                icon: Icon(Icons.translate),
              ),
            ],
            selected: {settings.languageCode},
            onSelectionChanged: (selection) {
              settings.setLanguage(selection.first);
            },
          ),
          const SizedBox(height: 12),
          Text(
            s.settingsHint,
            style: TextStyle(
              fontSize: 12.5,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

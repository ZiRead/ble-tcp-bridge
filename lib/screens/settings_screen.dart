import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../services/settings_controller.dart';

/// Вкладка «Настройки»: выбор языка приложения.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static final Uri _githubUri =
      Uri.parse('https://github.com/ZiRead/ble-tcp-bridge');

  Future<void> _openGithub() async {
    await launchUrl(_githubUri, mode: LaunchMode.externalApplication);
  }

  void _showAboutDialog(BuildContext context, AppStrings s) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.aboutTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close),
                        tooltip: s.aboutClose,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.aboutDescription,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _openGithub,
                    icon: const Icon(Icons.link),
                    label: Text(s.aboutGithub),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.aboutLicense,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(s.aboutClose),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

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
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(s.settingsAbout),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAboutDialog(context, s),
          ),
        ],
      ),
    );
  }
}

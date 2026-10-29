import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../services/settings_controller.dart';

/// Вкладка «Настройки»: выбор языка приложения.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static final Uri _githubUri =
      Uri.parse('https://github.com/ZiRead/ble-tcp-bridge');

  static const List<int> _baudRates = [
    9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600
  ];

  Future<void> _openGithub() async {
    await launchUrl(_githubUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _requestPermissions(BuildContext context, AppStrings s) async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.notification,
    ].request();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.settingsPermissionsRequested)),
    );
  }

  Future<void> _showTerminalSettingsDialog(
    BuildContext context,
    AppStrings s,
    SettingsController settings,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: Text(s.terminalSettings),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      // ignore: deprecated_member_use
                      value: [5, 6, 7, 8].contains(settings.terminalDataBits)
                          ? settings.terminalDataBits
                          : 8,
                      decoration: InputDecoration(labelText: s.terminalDataBits),
                      items: const [7, 8]
                          .map((v) => DropdownMenuItem<int>(
                                value: v,
                                child: Text('$v'),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          settings.setTerminalDataBits(v);
                          setState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      // ignore: deprecated_member_use
                      value: [1, 2, 3].contains(settings.terminalStopBits)
                          ? settings.terminalStopBits
                          : 1,
                      decoration: InputDecoration(labelText: s.terminalStopBits),
                      items: const [1, 2]
                          .map((v) => DropdownMenuItem<int>(
                                value: v,
                                child: Text('$v'),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          settings.setTerminalStopBits(v);
                          setState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      // ignore: deprecated_member_use
                      value: settings.terminalParity.clamp(0, 2),
                      decoration: InputDecoration(labelText: s.terminalParity),
                      items: [
                        DropdownMenuItem<int>(value: 0, child: Text(s.parityNone)),
                        DropdownMenuItem<int>(value: 1, child: Text(s.parityOdd)),
                        DropdownMenuItem<int>(value: 2, child: Text(s.parityEven)),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          settings.setTerminalParity(v);
                          setState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      // ignore: deprecated_member_use
                      value: settings.terminalFlowControl.clamp(0, 3),
                      decoration:
                          InputDecoration(labelText: s.terminalFlowControl),
                      items: [
                        DropdownMenuItem<int>(value: 0, child: Text(s.flowNone)),
                        DropdownMenuItem<int>(value: 1, child: Text(s.flowRtsCts)),
                        DropdownMenuItem<int>(value: 2, child: Text(s.flowDsrDtr)),
                        DropdownMenuItem<int>(value: 3, child: Text(s.flowXonXoff)),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          settings.setTerminalFlowControl(v);
                          setState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: ['\n', '\r', '\r\n'].contains(settings.terminalLineEnding)
                          ? settings.terminalLineEnding
                          : '\n',
                      decoration:
                          InputDecoration(labelText: s.terminalLineEnding),
                      items: [
                        DropdownMenuItem<String>(
                            value: '\n', child: Text(s.lineEndingLF)),
                        DropdownMenuItem<String>(
                            value: '\r', child: Text(s.lineEndingCR)),
                        DropdownMenuItem<String>(
                            value: '\r\n', child: Text(s.lineEndingCRLF)),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          settings.setTerminalLineEnding(v);
                          setState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      // ignore: deprecated_member_use
                      value: settings.terminalRxHex ? 1 : 0,
                      decoration: InputDecoration(labelText: s.terminalRxDisplay),
                      items: [
                        DropdownMenuItem<int>(value: 0, child: Text(s.displayAscii)),
                        DropdownMenuItem<int>(value: 1, child: Text(s.displayHex)),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          settings.setTerminalRxHex(v == 1);
                          setState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      // ignore: deprecated_member_use
                      value: settings.terminalTxHex ? 1 : 0,
                      decoration: InputDecoration(labelText: s.terminalTxDisplay),
                      items: [
                        DropdownMenuItem<int>(value: 0, child: Text(s.displayAscii)),
                        DropdownMenuItem<int>(value: 1, child: Text(s.displayHex)),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          settings.setTerminalTxHex(v == 1);
                          setState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: Text(s.terminalAutoScroll),
                      value: settings.terminalAutoScroll,
                      onChanged: (v) {
                        settings.setTerminalAutoScroll(v);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(s.aboutClose),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _checkUpdates(BuildContext context, AppStrings s) async {
    try {
      final client = HttpClient();
      final req = await client.getUrl(
        Uri.parse('https://api.github.com/repos/ZiRead/ble-tcp-bridge/releases/latest'),
      );
      req.headers.set('Accept', 'application/vnd.github+json');
      req.headers.set('User-Agent', 'ble-tcp-bridge');
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      client.close();
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final json = jsonDecode(body) as Map<String, dynamic>;
      final latestTag = (json['tag_name'] as String? ?? '').replaceFirst('v', '');
      final url = json['html_url'] as String? ??
          'https://github.com/ZiRead/ble-tcp-bridge/releases';
      final info = await PackageInfo.fromPlatform();
      if (!context.mounted) return;
      if (_isNewer(latestTag, info.version)) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(s.updateAvailable),
            content: Text(latestTag),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(s.aboutClose),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final uri = Uri.parse(url);
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                child: Text(s.updateOpen),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.updateUpToDate)),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.updateError)),
      );
    }
  }

  bool _isNewer(String latest, String current) {
    final l = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final n = l.length > c.length ? l.length : c.length;
    for (var i = 0; i < n; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv != cv) return lv > cv;
    }
    return false;
  }

  Future<void> _showAboutDialog(BuildContext context, AppStrings s) async {
    final info = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
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
                  const SizedBox(height: 12),
                  Text(
                    '${s.aboutVersion}: ${info.version}+${info.buildNumber}',
                    style: const TextStyle(fontSize: 13),
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

    if (settings.terminalSettingsRequested) {
      settings.clearTerminalSettingsRequest();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showTerminalSettingsDialog(context, s, settings);
      });
    }

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
          StatefulBuilder(
            builder: (context, setLocalState) {
              final usbCustom = !_baudRates.contains(settings.usbBaudRate);
              final customController =
                  TextEditingController(text: usbCustom ? '${settings.usbBaudRate}' : '');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    // ignore: deprecated_member_use
                    value: usbCustom ? -1 : settings.usbBaudRate,
                    decoration: InputDecoration(
                      labelText: s.settingsUsbBaudRate,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      ..._baudRates.map((b) => DropdownMenuItem<int>(
                            value: b,
                            child: Text('$b'),
                          )),
                      DropdownMenuItem<int>(
                        value: -1,
                        child: Text(s.customBaudRate),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      if (v == -1) {
                        setLocalState(() {});
                      } else {
                        settings.setUsbBaudRate(v);
                        setLocalState(() {});
                      }
                    },
                  ),
                  if (usbCustom) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: customController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: s.customBaudRate,
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (v) {
                        final parsed = int.tryParse(v.trim());
                        if (parsed != null && parsed > 0) {
                          settings.setUsbBaudRate(parsed);
                        }
                      },
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: Text(s.settingsDisableNonSerial),
            value: settings.disableNonSerialDevices,
            onChanged: (v) => settings.setDisableNonSerialDevices(v),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.terminal),
            title: Text(s.terminalSettings),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showTerminalSettingsDialog(context, s, settings),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.security),
            title: Text(s.settingsRequestPermissions),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _requestPermissions(context, s),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.system_update),
            title: Text(s.settingsCheckUpdates),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _checkUpdates(context, s),
          ),
          const SizedBox(height: 12),
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

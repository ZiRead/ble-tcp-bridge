import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/settings_controller.dart';
import 'devices_screen.dart';
import 'settings_screen.dart';
import 'tcp_screen.dart';
import 'terminal_screen.dart';

/// Главный экран с нижней навигацией:
/// «Устройства», «TCP сервер», «Терминал», «Настройки».
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  void setTab(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>().s;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const DevicesScreen(),
          const TcpScreen(),
          TerminalScreen(
            onOpenTerminalSettings: () => setState(() => _index = 3),
          ),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.devices_other_outlined),
            selectedIcon: const Icon(Icons.devices_other),
            label: s.tabDevices,
          ),
          NavigationDestination(
            icon: const Icon(Icons.dns_outlined),
            selectedIcon: const Icon(Icons.dns),
            label: s.tabTcp,
          ),
          NavigationDestination(
            icon: const Icon(Icons.terminal_outlined),
            selectedIcon: const Icon(Icons.terminal),
            label: s.tabTerminal,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: s.tabSettings,
          ),
        ],
      ),
    );
  }
}

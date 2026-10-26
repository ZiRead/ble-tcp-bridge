import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/ble_service.dart';
import 'services/bridge_controller.dart';
import 'services/tcp_server_service.dart';
import 'services/usb_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final bleService = BleService();
  final usbService = UsbService();
  final tcpServer = TcpServerService();
  final bridge = BridgeController(
    bleService: bleService,
    usbService: usbService,
    tcpServer: tcpServer,
  );

  runApp(BleTcpBridgeApp(bridge: bridge));
}

class BleTcpBridgeApp extends StatelessWidget {
  final BridgeController bridge;

  const BleTcpBridgeApp({super.key, required this.bridge});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: bridge,
      child: MaterialApp(
        title: 'BLE/USB TCP Bridge',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0066FF),
            brightness: Brightness.light,
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0066FF),
            brightness: Brightness.dark,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
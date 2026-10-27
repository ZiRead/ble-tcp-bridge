import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/ble_service.dart';
import 'services/bridge_controller.dart';
import 'services/bt_classic_service.dart';
import 'services/foreground_service.dart';
import 'services/settings_controller.dart';
import 'services/tcp_server_service.dart';
import 'services/usb_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = SettingsController();
  final bleService = BleService(settings: settings);
  final classicService = BtClassicService(settings: settings);
  final usbService = UsbService(settings: settings);
  final tcpServer = TcpServerService(settings: settings);
  final bridge = BridgeController(
    bleService: bleService,
    classicService: classicService,
    usbService: usbService,
    tcpServer: tcpServer,
    settings: settings,
  );

  runApp(BleTcpBridgeApp(bridge: bridge, settings: settings));
}

class BleTcpBridgeApp extends StatefulWidget {
  final BridgeController bridge;
  final SettingsController settings;

  const BleTcpBridgeApp({
    super.key,
    required this.bridge,
    required this.settings,
  });

  @override
  State<BleTcpBridgeApp> createState() => _BleTcpBridgeAppState();
}

class _BleTcpBridgeAppState extends State<BleTcpBridgeApp> {
  @override
  void initState() {
    super.initState();
    TcpForegroundService.stop().catchError((_) {});
    widget.settings.load();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.bridge),
        ChangeNotifierProvider.value(value: widget.settings),
      ],
      child: Consumer<SettingsController>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: settings.s.appTitle,
            debugShowCheckedModeBanner: false,
            locale: settings.locale,
            supportedLocales: const [Locale('ru'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
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
          );
        },
      ),
    );
  }
}

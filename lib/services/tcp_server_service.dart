import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'foreground_service.dart';
import 'settings_controller.dart';

/// Локальный TCP-сервер, который пробрасывает данные
/// между serial-устройством и TCP-клиентами.
class TcpServerService {
  final SettingsController? settings;
  TcpServerService({this.settings});
  static const int defaultPort = 8080;

  ServerSocket? _server;
  final Set<Socket> _clients = {};
  int _port = defaultPort;

  bool _running = false;
  bool get isRunning => _running;
  int get port => _port;
  int get clientCount => _clients.length;

  /// Поток входящих данных от TCP-клиентов (их нужно писать в serial).
  final _fromClients = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get onDataFromClients => _fromClients.stream;

  /// Поток событий сервера (подключения, ошибки).
  final _events = StreamController<String>.broadcast();
  Stream<String> get onEvent => _events.stream;

  /// Запустить сервер на указанном порту.
  Future<void> start({int port = defaultPort}) async {
    if (_running) return;
    _port = port;

    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      _running = true;
      _events.add(settings?.s.tcpServerStarted(port) ??
          'Сервер запущен на порту $port');

      // Фоновый сервис с уведомлением
      TcpForegroundService.start(
        title: settings?.s.serverRunning ?? 'TCP server running',
        text: 'Port $port',
        bigText:
            '${settings?.s.serverRunning ?? 'TCP server running'}\nPort: $port\nClients: ${_clients.length}',
      );

      _server!.listen((client) {
        _clients.add(client);
        _events.add(settings?.s.tcpClientConnected(
                client.remoteAddress.address, _clients.length) ??
            'Клиент подключён: ${client.remoteAddress.address} '
                '(всего: ${_clients.length})');

        TcpForegroundService.update(
          title: settings?.s.serverRunning ?? 'TCP server running',
          text: 'Port $_port  •  Clients: ${_clients.length}',
          bigText:
              '${settings?.s.serverRunning ?? 'TCP server running'}\nPort: $_port\nClients: ${_clients.length}',
        );

        client.listen(
          (data) {
            _fromClients.add(Uint8List.fromList(data));
          },
          onError: (_) => _removeClient(client),
          onDone: () => _removeClient(client),
          cancelOnError: true,
        );
      });
    } catch (e) {
      _events.add(settings?.s.tcpServerError(e) ?? 'Ошибка запуска сервера: $e');
      rethrow;
    }
  }

  /// Остановить сервер и закрыть всех клиентов.
  Future<void> stop() async {
    if (!_running) return;
    _running = false;

    TcpForegroundService.stop();

    for (final c in List.of(_clients)) {
      try {
        await c.close();
      } catch (_) {}
    }
    _clients.clear();

    try {
      await _server?.close();
    } catch (_) {}
    _server = null;
    _events.add(settings?.s.tcpServerStopped ?? 'Сервер остановлен');
  }

  /// Отправить данные всем подключённым TCP-клиентам.
  Future<void> broadcast(Uint8List data) async {
    if (!_running || _clients.isEmpty) return;
    for (final c in List.of(_clients)) {
      try {
        c.add(data);
      } catch (_) {
        _removeClient(c);
      }
    }
  }

  void _removeClient(Socket client) {
    if (_clients.remove(client)) {
      _events.add(settings?.s.tcpClientDisconnected(
              client.remoteAddress.address, _clients.length) ??
          'Клиент отключён: ${client.remoteAddress.address} '
              '(всего: ${_clients.length})');
    }
  }

  void dispose() {
    _fromClients.close();
    _events.close();
  }
}
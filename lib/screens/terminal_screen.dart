import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/bridge_controller.dart';
import '../services/settings_controller.dart';
import '../services/serial_port.dart';
import '../widgets/status_banner.dart';

/// Вкладка «Терминал»: прямой доступ к serial-устройству.
class TerminalScreen extends StatefulWidget {
  final VoidCallback? onOpenTerminalSettings;
  const TerminalScreen({super.key, this.onOpenTerminalSettings});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _lines = <String>[];
  StreamSubscription<Uint8List>? _sub;
  SerialPort? _currentPort;

  final List<String> _commandHistory = <String>[];
  final List<int> _historyLineIndices = <int>[];
  int _historyIndex = -1;
  String _savedInput = '';
  int? _selectedLineIndex;

  static const List<double> _fontSizes = [10, 12, 14, 16, 18, 20];
  static const List<Color> _textColors = [
    Colors.greenAccent,
    Colors.white,
    Colors.amber,
    Colors.cyanAccent,
    Colors.redAccent,
  ];
  static const List<Color> _bgColors = [
    Colors.black,
    Color(0xFF1E1E1E),
    Color(0xFF0D1B2A),
    Color(0xFF1A237E),
  ];

  @override
  void initState() {
    super.initState();
    _bindToPort();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindToPort();
  }

  void _bindToPort() {
    final bridge = context.read<BridgeController>();
    final port = bridge.port;
    if (port == _currentPort) return;
    _currentPort = port;
    _sub?.cancel();
    _sub = null;
    if (port != null) {
      _sub = port.inputStream.listen((data) {
        if (!mounted) return;
        final settings = context.read<SettingsController>();
        final text = settings.terminalRxHex
            ? data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')
            : utf8.decode(data, allowMalformed: true);
        setState(() {
          final parts = text.split('\n');
          for (var i = 0; i < parts.length; i++) {
            if (i == 0) {
              if (_lines.isEmpty) {
                _lines.add(parts[i]);
              } else {
                _lines[_lines.length - 1] += parts[i];
              }
            } else {
              _lines.add(parts[i]);
            }
          }
          if (_lines.length > 1000) {
            _lines.removeRange(0, _lines.length - 1000);
          }
        });
        if (!mounted) return;
        if (context.read<SettingsController>().terminalAutoScroll) _scrollToBottom();
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final bridge = context.read<BridgeController>();
    final settings = context.read<SettingsController>();
    final port = bridge.port;
    final text = _inputController.text;
    if (port == null || text.isEmpty) return;
    final lineEnding = settings.terminalLineEnding;
    final data = Uint8List.fromList(utf8.encode('$text$lineEnding'));
    await port.write(data);
    setState(() {
      if (settings.terminalTxHex) {
        _lines.add('> ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      } else {
        _lines.add('> $text');
      }
      _commandHistory.add(text);
      _historyLineIndices.add(_lines.length - 1);
      _historyIndex = -1;
      _savedInput = '';
      _selectedLineIndex = null;
    });
    _inputController.clear();
    if (settings.terminalAutoScroll) _scrollToBottom();
  }

  void _historyUp() {
    if (_commandHistory.isEmpty) return;
    if (_historyIndex == -1) {
      _savedInput = _inputController.text;
    }
    if (_historyIndex < _commandHistory.length - 1) {
      _historyIndex++;
      final cmd = _commandHistory[_commandHistory.length - 1 - _historyIndex];
      final lineIndex = _historyLineIndices[_commandHistory.length - 1 - _historyIndex];
      _inputController.text = cmd;
      _inputController.selection = TextSelection.collapsed(offset: cmd.length);
      setState(() => _selectedLineIndex = lineIndex);
    }
  }

  void _historyDown() {
    if (_historyIndex <= 0) {
      _historyIndex = -1;
      _inputController.text = _savedInput;
      _inputController.selection = TextSelection.collapsed(offset: _savedInput.length);
      setState(() => _selectedLineIndex = null);
      return;
    }
    _historyIndex--;
    final cmd = _commandHistory[_commandHistory.length - 1 - _historyIndex];
    final lineIndex = _historyLineIndices[_commandHistory.length - 1 - _historyIndex];
    _inputController.text = cmd;
    _inputController.selection = TextSelection.collapsed(offset: cmd.length);
    setState(() => _selectedLineIndex = lineIndex);
  }

  Future<void> _exportLog() async {
    try {
      final path = await FilePicker.saveFile(
        dialogTitle: 'Save terminal log',
        fileName: 'terminal_log.txt',
        bytes: Uint8List.fromList(utf8.encode(_lines.join('\n'))),
      );
      if (path == null) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }
  @override
  void dispose() {
    _sub?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bridge = context.watch<BridgeController>();
    final settings = context.watch<SettingsController>();
    final s = settings.s;

    if (bridge.port != _currentPort) {
      _bindToPort();
    }

    final port = bridge.port;
    final fontSize = settings.terminalFontSize;
    final textColor = _textColors[
        settings.terminalTextColor.clamp(0, _textColors.length - 1)];
    final bgColor = _bgColors[
        settings.terminalBgColor.clamp(0, _bgColors.length - 1)];

    final selectedLineIndex = _selectedLineIndex;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(s.tabTerminal),
        centerTitle: true,
      ),
      body: Column(
        children: [
          StatusBanner(bridge: bridge),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(s.terminalFontSize, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  DropdownButton<double>(
                    value: _fontSizes.contains(fontSize) ? fontSize : 14,
                    items: _fontSizes
                        .map((f) => DropdownMenuItem<double>(
                              value: f,
                              child: Text('${f.toInt()}'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) settings.setTerminalFontSize(v);
                    },
                  ),
                  const SizedBox(width: 12),
                  Text(s.terminalTextColor, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  DropdownButton<int>(
                    value: settings.terminalTextColor.clamp(0, _textColors.length - 1),
                    items: List.generate(
                      _textColors.length,
                      (i) => DropdownMenuItem<int>(
                        value: i,
                        child: Container(
                          width: 16,
                          height: 16,
                          color: _textColors[i],
                        ),
                      ),
                    ),
                    onChanged: (v) {
                      if (v != null) settings.setTerminalTextColor(v);
                    },
                  ),
                  const SizedBox(width: 12),
                  Text(s.terminalBgColor, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  DropdownButton<int>(
                    value: settings.terminalBgColor.clamp(0, _bgColors.length - 1),
                    items: List.generate(
                      _bgColors.length,
                      (i) => DropdownMenuItem<int>(
                        value: i,
                        child: Container(
                          width: 16,
                          height: 16,
                          color: _bgColors[i],
                        ),
                      ),
                    ),
                    onChanged: (v) {
                      if (v != null) settings.setTerminalBgColor(v);
                    },
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Container(
              color: bgColor,
              padding: const EdgeInsets.all(8),
              child: port == null
                  ? Center(
                      child: Text(
                        s.terminalNoDevice,
                        style: TextStyle(color: textColor, fontSize: fontSize),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _lines.length,
                      itemBuilder: (context, index) {
                        final line = _lines[index];
                        final isSelected = selectedLineIndex != null &&
                            index == selectedLineIndex;
                        return Text(
                          line,
                          style: TextStyle(
                            color: isSelected ? bgColor : textColor,
                            backgroundColor: isSelected ? textColor : null,
                            fontSize: fontSize,
                            fontFamily: 'monospace',
                          ),
                        );
                      },
                    ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.save_alt, size: 20),
                            onPressed: _exportLog,
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings, size: 20),
                            onPressed: () {
                              final settings = context.read<SettingsController>();
                              settings.requestTerminalSettings();
                              widget.onOpenTerminalSettings?.call();
                            },
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_up),
                            onPressed: _historyUp,
                          ),
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_down),
                            onPressed: _historyDown,
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          style: const TextStyle(fontFamily: 'monospace'),
                          decoration: InputDecoration(
                            hintText: s.terminalInputHint,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _send,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

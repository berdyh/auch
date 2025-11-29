import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'services/cactus_brain.dart';
import 'services/model_manager.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auch Agent',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const AgentScreen(),
    );
  }
}

class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class LogEntry {
  final DateTime timestamp;
  final String message;
  final Color color;

  LogEntry(this.message, {Color? color}) 
      : timestamp = DateTime.now(),
        this.color = color ?? Colors.black;
}

class _AgentScreenState extends State<AgentScreen> {
  final TextEditingController _goalController = TextEditingController();
  final CactusBrain _brain = CactusBrain();
  static const platform = MethodChannel('com.minitap.device/agent');
  final ScrollController _scrollController = ScrollController();

  bool _isRunning = false;
  final List<LogEntry> _logs = [];
  String _currentImage = "";

  @override
  void initState() {
    super.initState();
    _initSequence();
  }

  Future<void> _initSequence() async {
    final abiOk = await _checkAbiSupport();
    if (!abiOk) {
      _log("Unsupported ABI. This build ships native libs for arm64-v8a only. Use an ARM64 device/emulator.", color: Colors.red);
      return;
    }

    final hasModel = await ModelManager.ensureModelExists(
      onProgress: (status) {
        _log(status, color: Colors.blue);
      }
    );
    if (!hasModel) {
      if (mounted) {
        _showModelMissingDialog();
      }
      return;
    }

    final modelPath = await ModelManager.getModelPath();
    await _checkPermissions();
    // Cactus expects just the filename relative to its models dir
    await _brain.init(ModelManager.modelName);
    _log("Brain initialized.", color: Colors.green);
  }

  Future<void> _checkPermissions() async {
    // We use app-specific cache dir, so mostly no explicit storage permissions needed for API 19+
    // But depending on how assets are copied or if we need to read the model, we might need basic storage on older devices.
    // However, since we removed MANAGE_EXTERNAL_STORAGE, we just do a basic check/request if needed or skip.
    // For now, we will skip explicit requests as we are using internal cacheDir.
  }

  Future<bool> _checkAbiSupport() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final abis = info.supportedAbis;
      if (abis.any((abi) => abi.contains("arm64"))) {
        return true;
      }
      return false;
    } catch (_) {
      // If we cannot detect, assume unsupported to avoid crashing on x86 emulator.
      return false;
    }
  }

  Future<bool> _isServiceActive() async {
    try {
      final bool result = await platform.invokeMethod('isServiceActive');
      return result;
    } on PlatformException catch (e) {
      _log("Error checking service: ${e.message}", color: Colors.red);
      return false;
    }
  }

  void _log(String message, {Color? color}) {
    setState(() {
      _logs.insert(0, LogEntry(message, color: color));
    });
  }

  void _stopAgent() {
    setState(() {
      _isRunning = false;
    });
    _log("Agent stopped.", color: Colors.red);
  }

  Future<void> _startAgent() async {
    if (_goalController.text.isEmpty) {
      _log("Please enter a goal.", color: Colors.orange);
      return;
    }

    bool serviceActive = await _isServiceActive();
    if (!serviceActive) {
      _showServiceDialog();
      return;
    }

    setState(() {
      _isRunning = true;
      _logs.clear();
      _log("Agent Started...", color: Colors.green);
    });

    while (_isRunning) {
      try {
        // 1. Capture State
        _log("Capturing state...");
        final result = await platform.invokeMethod('captureState');
        // result is Map with imagePath and uiTree
        // But invokeMethod returns dynamic, we need to cast safely
        final Map<dynamic, dynamic> resultMap = result as Map<dynamic, dynamic>;
        final String imagePath = resultMap['imagePath'];
        final String uiTree = resultMap['uiTree'];

        setState(() {
          _currentImage = imagePath;
        });

        // 2. Ask Brain
        _log("Analyzing...", color: Colors.blue);
        final AgentResponse response = await _brain.ask(
          imagePath,
          uiTree,
          _goalController.text
        );

        _log("Analysis: ${response.analysis}", color: Colors.purple);
        _log("Plan: ${response.plan}", color: Colors.deepPurple);

        // 3. Act
        if (response.elementId != null) {
          final uiTreeList = jsonDecode(uiTree) as List<dynamic>;
          final targetNode = uiTreeList.firstWhere(
            (node) => node['id'] == response.elementId,
            orElse: () => null,
          );

          if (targetNode != null) {
            final bounds = targetNode['bounds'] as List<dynamic>;
            final x = bounds[0] + (bounds[2] / 2);
            final y = bounds[1] + (bounds[3] / 2);

            _log("Action: Tap at ($x, $y)", color: Colors.green);
            await platform.invokeMethod('performAction', {
              'x': x.toInt(),
              'y': y.toInt()
            });
          } else {
             _log("Target element ${response.elementId} not found in current tree.", color: Colors.orange);
          }
        } else {
           _log("No action determined.", color: Colors.orange);
        }

        // 4. Wait
        _log("Waiting for transition...");
        await Future.delayed(const Duration(seconds: 3));

      } catch (e) {
        _log("Error in loop: $e", color: Colors.red);
        _stopAgent();
      }
    }
  }

  void _showServiceDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Enable Accessibility"),
        content: const Text("Please enable the 'Auch' Accessibility Service in Android Settings to allow the agent to see and touch the screen."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK")
          )
        ],
      )
    );
  }

  void _showModelMissingDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Model Missing"),
        content: const Text("The 'LFM2-VL-1.6B.gguf' model was not found in assets. Please add it to the device manually or bundle it with the app."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK")
          )
        ],
      )
    );
  }

  @override
  void dispose() {
    _brain.dispose();
    _goalController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auch Agent')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _goalController,
              decoration: const InputDecoration(
                labelText: 'Goal',
                hintText: 'e.g., Open Settings and turn on WiFi',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _isRunning ? null : _startAgent,
                child: const Text("Start Agent"),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: _isRunning ? _stopAgent : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade100),
                child: const Text("Stop"),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: Container(
              color: Colors.grey.shade100,
              width: double.infinity,
              padding: const EdgeInsets.all(8.0),
              child: ListView.builder(
                controller: _scrollController,
                reverse: true, // Newest at bottom if we appended, but we insert at 0 so reverse: false? 
                // Wait, I used insert(0, ...) so newest is at top. 
                // If I want standard log view (newest at bottom), I should add() and use reverse: true?
                // Actually, insert(0) puts it at index 0. ListView starts at index 0 at top.
                // So newest is at top. That's fine for mobile.
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontFamily: 'Monospace', fontSize: 12, color: Colors.black87),
                        children: [
                          TextSpan(
                            text: "[${log.timestamp.hour}:${log.timestamp.minute}:${log.timestamp.second}] ",
                            style: const TextStyle(color: Colors.grey),
                          ),
                          TextSpan(
                            text: log.message,
                            style: TextStyle(color: log.color, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

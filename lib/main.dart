import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
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

class _AgentScreenState extends State<AgentScreen> {
  final TextEditingController _goalController = TextEditingController();
  final CactusBrain _brain = CactusBrain();
  static const platform = MethodChannel('com.minitap.device/agent');

  bool _isRunning = false;
  String _statusLog = "Ready.";
  String _currentImage = "";

  @override
  void initState() {
    super.initState();
    _initSequence();
  }

  Future<void> _initSequence() async {
    final hasModel = await ModelManager.ensureModelExists();
    if (!hasModel) {
      if (mounted) {
        _showModelMissingDialog();
      }
      return;
    }

    final modelPath = await ModelManager.getModelPath();
    await _checkPermissions();
    await _brain.init(modelPath);
  }

  Future<void> _checkPermissions() async {
    // We use app-specific cache dir, so mostly no explicit storage permissions needed for API 19+
    // But depending on how assets are copied or if we need to read the model, we might need basic storage on older devices.
    // However, since we removed MANAGE_EXTERNAL_STORAGE, we just do a basic check/request if needed or skip.
    // For now, we will skip explicit requests as we are using internal cacheDir.
  }

  Future<bool> _isServiceActive() async {
    try {
      final bool result = await platform.invokeMethod('isServiceActive');
      return result;
    } on PlatformException catch (e) {
      _log("Error checking service: ${e.message}");
      return false;
    }
  }

  void _log(String message) {
    setState(() {
      _statusLog = "$message\n$_statusLog";
    });
  }

  void _stopAgent() {
    setState(() {
      _isRunning = false;
    });
    _log("Agent stopped.");
  }

  Future<void> _startAgent() async {
    if (_goalController.text.isEmpty) {
      _log("Please enter a goal.");
      return;
    }

    bool serviceActive = await _isServiceActive();
    if (!serviceActive) {
      _showServiceDialog();
      return;
    }

    setState(() {
      _isRunning = true;
      _statusLog = "Agent Started...";
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
        _log("Analyzing...");
        final AgentResponse response = await _brain.ask(
          imagePath,
          uiTree,
          _goalController.text
        );

        _log("Analysis: ${response.analysis}");
        _log("Plan: ${response.plan}");

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

            _log("Action: Tap at ($x, $y)");
            await platform.invokeMethod('performAction', {
              'x': x.toInt(),
              'y': y.toInt()
            });
          } else {
             _log("Target element ${response.elementId} not found in current tree.");
          }
        } else {
           _log("No action determined.");
        }

        // 4. Wait
        _log("Waiting for transition...");
        await Future.delayed(const Duration(seconds: 3));

      } catch (e) {
        _log("Error in loop: $e");
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
              color: Colors.black12,
              width: double.infinity,
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                reverse: true,
                child: Text(
                  _statusLog,
                  style: const TextStyle(fontFamily: 'Monospace'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

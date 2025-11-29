import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:cactus/cactus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'services/cactus_brain.dart';
import 'services/model_config.dart';

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
  double? _downloadProgress;
  
  // Visual feedback state
  String _currentAnalysis = "";
  String _currentPlan = "";
  String _currentAction = "";
  Offset? _lastTapLocation;
  bool _showTapIndicator = false;

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

    // Show model selection dialog
    if (mounted) {
      final modelSlug = await _showModelSelectionDialog();
      if (modelSlug == null) {
        _log("No model selected", color: Colors.orange);
        return;
      }

      // await _checkPermissions(); // No longer needed for app documents directory
      
      // Initialize brain with the selected model slug
      await _brain.init(
        modelSlug,
        onDownloadProgress: (progress) {
          setState(() {
            _downloadProgress = progress;
          });
        },
        onLog: (status) {
          // Only log significant events, not every download chunk
          if (status.contains("Error") || status.contains("Downloading") || status.contains("Initializing")) {
            _log(status, color: status.contains("Error") ? Colors.red : Colors.blue);
          }
        },
      );

      setState(() {
       _downloadProgress = null;
      });

      _log("Brain initialized with $modelSlug", color: Colors.green);
    }
  }

  Future<String?> _showModelSelectionDialog() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Model'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Choose a model to download and use:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...ModelConfig.availableModels.entries.map((entry) {
                  final name = entry.key;
                  final info = entry.value;
                  return ListTile(
                    leading: const Icon(Icons.download_outlined),
                    title: Text(name),
                    subtitle: Text(info.description),
                    onTap: () {
                      Navigator.of(context).pop(info.slug);
                    },
                  );
                }).toList(),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(null);
              },
            ),
          ],
        );
      },
    );
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

  void _stopAgent() async {
    setState(() {
      _isRunning = false;
    });

    // Disable wake lock
    try {
      await WakelockPlus.disable();
      _log("Wake lock disabled", color: Colors.grey);
    } catch (e) {
      _log("Failed to disable wake lock: $e", color: Colors.orange);
    }

    // Stop foreground service
    try {
      platform.invokeMethod('stopForegroundService');
      _log("Foreground service stopped", color: Colors.grey);
    } catch (e) {
      _log("Failed to stop foreground service: $e", color: Colors.orange);
    }

    _log("Agent stopped by user", color: Colors.red);
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

    // Start foreground service to keep app alive
    try {
      await platform.invokeMethod('startForegroundService');
      _log("Foreground service started", color: Colors.green);
    } catch (e) {
      _log("Failed to start foreground service: $e", color: Colors.orange);
    }

    // Enable wake lock to keep CPU active
    try {
      await WakelockPlus.enable();
      _log("Wake lock enabled - CPU will stay active", color: Colors.green);
    } catch (e) {
      _log("Failed to enable wake lock: $e", color: Colors.orange);
    }

    setState(() {
      _isRunning = true;
      _logs.clear();
      _log("Agent Started...", color: Colors.green);
    });

    _runAgentLoop();
  }

  Future<void> _runAgentLoop() async {
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

        // Update visual feedback
        setState(() {
          _currentAnalysis = response.analysis;
          _currentPlan = response.plan;
          _currentAction = response.action;
        });

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

            // Show tap indicator
            setState(() {
              _lastTapLocation = Offset(x.toDouble(), y.toDouble());
              _showTapIndicator = true;
            });

            _log("Action: Tap at ($x, $y)", color: Colors.green);
            await platform.invokeMethod('performAction', {
              'x': x.toInt(),
              'y': y.toInt()
            });

            // Hide tap indicator after a delay
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted) {
                setState(() {
                  _showTapIndicator = false;
                });
              }
            });
          } else {
             _log("Target element ${response.elementId} not found in current tree.", color: Colors.orange);
          }
        } else {
           _log("No action determined.", color: Colors.orange);
        }

        // 4. Wait
        await Future.delayed(const Duration(seconds: 3));

      } catch (e) {
        _log("Error: $e", color: Colors.red);
        // Don't stop on errors, just continue
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    _log("Agent stopped", color: Colors.grey);
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
      body: Stack(
        children: [
          // Main UI
          Column(
            children: [
              if (_downloadProgress != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text("Downloading Model..."),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: _downloadProgress),
                      const SizedBox(height: 4),
                      Text("${(_downloadProgress! * 100).toStringAsFixed(1)}%"),
                    ],
                  ),
                ),
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
              
              // Agent Status Display
              if (_isRunning && (_currentAnalysis.isNotEmpty || _currentPlan.isNotEmpty))
                Container(
                  margin: const EdgeInsets.all(8.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_currentAnalysis.isNotEmpty) ...([
                        const Text("🔍 Analysis:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text(_currentAnalysis, style: const TextStyle(fontSize: 11)),
                        const SizedBox(height: 4),
                      ]),
                      if (_currentPlan != "none" && _currentPlan.isNotEmpty) ...([
                        const Text("📋 Plan:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text(_currentPlan, style: const TextStyle(fontSize: 11)),
                        const SizedBox(height: 4),
                      ]),
                      if (_currentAction != "none" && _currentAction.isNotEmpty) ...([
                        const Text("⚡ Action:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
                        Text(_currentAction.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                      ]),
                    ],
                  ),
                ),

              const Divider(),
              Expanded(
                child: Container(
                  color: Colors.grey.shade100,
                  width: double.infinity,
                  padding: const EdgeInsets.all(8.0),
                  child: ListView.builder(
                    controller: _scrollController,
                    reverse: true,
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
          
          // Tap indicator overlay
          if (_showTapIndicator && _lastTapLocation != null)
            Positioned(
              left: _lastTapLocation!.dx - 40,
              top: _lastTapLocation!.dy - 40,
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: 1.0 - value,
                      child: Transform.scale(
                        scale: 1.0 + value * 0.5,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.green,
                              width: 4,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.touch_app,
                              color: Colors.green,
                              size: 32,
                            ),
                          ),
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

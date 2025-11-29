import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class ModelManager {
  static const String modelName = "LFM2-VL-1.6B.gguf";

  /// Checks if the model exists in the app's document directory.
  /// If not, attempts to copy it from assets.
  static Future<String> getModelPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$modelName';
  }

  static Future<bool> ensureModelExists() async {
    final path = await getModelPath();
    final modelFile = File(path);

    if (await modelFile.exists()) {
      print("Model found at: ${modelFile.path}");
      return true;
    }

    print("Model not found in storage. Attempting to copy from assets...");
    try {
      final byteData = await rootBundle.load('assets/models/$modelName');
      final buffer = byteData.buffer;
      await modelFile.writeAsBytes(
        buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes)
      );
      print("Model copied to: ${modelFile.path}");
      return true;
    } catch (e) {
      print("Error copying model from assets: $e");
      return false;
    }
  }
}

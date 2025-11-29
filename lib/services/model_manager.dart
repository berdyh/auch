import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ModelManager {
  static const String modelName = "LFM2-VL-1.6B.gguf";

  /// Checks if the model exists in the app's document directory.
  /// If not, attempts to copy it from a few common locations.
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

    // Try to locate the model in common shared locations (e.g., pushed via adb to Downloads)
    final candidateFiles = <File>[];
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        candidateFiles.add(File('${ext.path}/$modelName'));
      }
    } catch (_) {}
    candidateFiles.add(File('/storage/emulated/0/Download/$modelName'));

    for (final candidate in candidateFiles) {
      if (await candidate.exists()) {
        try {
          await modelFile.create(recursive: true);
          await candidate.copy(modelFile.path);
          print("Model copied from ${candidate.path} to ${modelFile.path}");
          return true;
        } catch (e) {
          print("Failed to copy model from ${candidate.path}: $e");
        }
      }
    }

    print("Model not found in app storage or common shared locations.");
    try {
      await modelFile.parent.create(recursive: true);
    } catch (e) {
      print("Failed creating model directory: $e");
    }
    return false;
  }
}

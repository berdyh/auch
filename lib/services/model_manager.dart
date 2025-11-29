import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ModelManager {
  static const String modelName = "LFM2-VL-1.6B.gguf";
  static const String modelUrl = "https://huggingface.co/bartowski/LiquidAI_LFM2-VL-1.6B-GGUF/resolve/main/LiquidAI_LFM2-VL-1.6B-Q5_K_M.gguf?download=true";

  /// Checks if the model exists in the app's document directory.
  /// If not, attempts to copy it from a few common locations.
  static Future<String> getModelPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$modelName';
  }

  static Future<bool> ensureModelExists({Function(String)? onProgress}) async {
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

    print("Model not found locally. Attempting download...");
    return await downloadModel(modelFile, onProgress);
  }

  static Future<bool> downloadModel(File targetFile, Function(String)? onProgress) async {
    try {
      await targetFile.parent.create(recursive: true);
      
      final request = await HttpClient().getUrl(Uri.parse(modelUrl));
      final response = await request.close();
      
      if (response.statusCode != 200) {
        print("Failed to download model: HTTP ${response.statusCode}");
        return false;
      }

      final contentLength = response.contentLength;
      int received = 0;
      
      final sink = targetFile.openWrite();
      await response.listen(
        (List<int> chunk) {
          received += chunk.length;
          sink.add(chunk);
          if (onProgress != null && contentLength > 0) {
            final percentage = (received / contentLength * 100).toStringAsFixed(1);
            onProgress("Downloading: $percentage% (${(received / 1024 / 1024).toStringAsFixed(1)} MB)");
          }
        },
        onDone: () async {
          await sink.close();
        },
        onError: (e) {
          print("Download error: $e");
          sink.close();
        },
        cancelOnError: true,
      ).asFuture();

      print("Model downloaded successfully to ${targetFile.path}");
      return true;
    } catch (e) {
      print("Exception during model download: $e");
      if (await targetFile.exists()) {
        await targetFile.delete(); // Clean up partial file
      }
      return false;
    }
  }
}

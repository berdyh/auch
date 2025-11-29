import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ModelInfo {
  final String fileName;
  final String displayName;
  final String url;
  final String description;
  final int minSizeBytes;

  const ModelInfo({
    required this.fileName,
    required this.displayName,
    required this.url,
    required this.description,
    required this.minSizeBytes,
  });
}

class ModelManager {
  // Available models catalog
  static final Map<String, ModelInfo> availableModels = {
    'gemma-2-2b': const ModelInfo(
      fileName: 'gemma-2-2b-it-Q4_K_M.gguf',
      displayName: 'Gemma 2 2B (Recommended)',
      url: 'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf?download=true',
      description: '1.6GB - Fast and efficient',
      minSizeBytes: 1200 * 1024 * 1024, // 1.2GB minimum
    ),
    'liquid-lfm2': const ModelInfo(
      fileName: 'lfm-2-1.6b-Q4_K_M.gguf',
      displayName: 'Liquid LFM2 1.6B',
      url: 'https://huggingface.co/mradermacher/lfm-2-1.6b-GGUF/resolve/main/lfm-2-1.6b.Q4_K_M.gguf?download=true',
      description: '1.0GB - Experimental',
      minSizeBytes: 800 * 1024 * 1024, // 800MB minimum
    ),
  };

  /// Get the file path for a specific model by its filename
  static Future<String> getModelPath(String modelFileName) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/models/$modelFileName';
  }

  /// Get list of model filenames that exist on device
  static Future<List<String>> getAvailableModels() async {
    final directory = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${directory.path}/models');
    if (!await modelsDir.exists()) return [];
    
    return modelsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.gguf'))
        .map((f) => f.uri.pathSegments.last)
        .toList();
  }

  /// Ensure a specific model exists, downloading if necessary
  static Future<bool> ensureModelExists(
    String modelKey, {
    Function(String)? onLog,
    Function(double)? onProgress,
  }) async {
    final modelInfo = availableModels[modelKey];
    if (modelInfo == null) {
      if (onLog != null) onLog('Unknown model: $modelKey');
      return false;
    }

    final path = await getModelPath(modelInfo.fileName);
    final modelFile = File(path);

    if (await modelFile.exists()) {
      final size = await modelFile.length();
      print("Model found at: ${modelFile.path} (Size: ${size / 1024 / 1024} MB)");
      
      // Check if file is complete
      if (size < modelInfo.minSizeBytes) {
        if (onLog != null) {
          onLog("Model file too small (<${modelInfo.minSizeBytes / 1024 / 1024}MB), deleting...");
        }
        await modelFile.delete();
        return await downloadModel(modelInfo, modelFile, onLog, onProgress);
      }
      return true;
    }

    // Try to locate the model in common shared locations
    final candidateFiles = <File>[];
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        candidateFiles.add(File('${ext.path}/${modelInfo.fileName}'));
      }
    } catch (_) {}
    candidateFiles.add(File('/storage/emulated/0/Download/${modelInfo.fileName}'));

    for (final candidate in candidateFiles) {
      if (await candidate.exists()) {
        try {
          await modelFile.create(recursive: true);
          if (onLog != null) onLog("Copying model from ${candidate.path}...");
          await candidate.copy(modelFile.path);
          if (onLog != null) onLog("Model copied successfully.");
          return true;
        } catch (e) {
          print("Failed to copy model from ${candidate.path}: $e");
        }
      }
    }

    if (onLog != null) onLog("Model not found locally. Downloading...");
    return await downloadModel(modelInfo, modelFile, onLog, onProgress);
  }

  static Future<bool> downloadModel(
    ModelInfo modelInfo,
    File targetFile,
    Function(String)? onLog,
    Function(double)? onProgress,
  ) async {
    try {
      await targetFile.parent.create(recursive: true);
      
      final request = await HttpClient().getUrl(Uri.parse(modelInfo.url));
      final response = await request.close();
      
      if (response.statusCode != 200) {
        print("Failed to download model: HTTP ${response.statusCode}");
        if (onLog != null) onLog("Failed to download: HTTP ${response.statusCode}");
        return false;
      }

      final contentLength = response.contentLength;
      int received = 0;
      
      final sink = targetFile.openWrite();
      await response.listen(
        (List<int> chunk) {
          received += chunk.length;
          sink.add(chunk);
          if (contentLength > 0) {
            final progress = received / contentLength;
            if (onProgress != null) onProgress(progress);
          }
        },
        onDone: () async {
          await sink.close();
        },
        onError: (e) {
          print("Download error: $e");
          if (onLog != null) onLog("Download error: $e");
          sink.close();
        },
        cancelOnError: true,
      ).asFuture();

      print("Model downloaded successfully to ${targetFile.path}");
      if (onLog != null) onLog("Model downloaded successfully.");
      return true;
    } catch (e) {
      print("Exception during model download: $e");
      if (onLog != null) onLog("Exception during download: $e");
      if (await targetFile.exists()) {
        await targetFile.delete(); // Clean up partial file
      }
      return false;
    }
  }
}

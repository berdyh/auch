import 'package:cactus/cactus.dart';
import 'dart:convert';
import '../agent/prompt_strategy.dart';

class AgentResponse {
  final String analysis;
  final String plan;
  final String action;
  final int? elementId;

  AgentResponse({
    required this.analysis,
    required this.plan,
    required this.action,
    this.elementId,
  });

  factory AgentResponse.fromJson(Map<String, dynamic> json) {
    return AgentResponse(
      analysis: json['analysis'] ?? '',
      plan: json['plan'] ?? '',
      action: json['action'] ?? '',
      elementId: json['element_id'],
    );
  }
}

class CactusBrain {
  final CactusLM _cactus = CactusLM();
  bool _isInitialized = false;
  String? _currentModelSlug;

  /// Initialize with a Cactus SDK model slug (e.g., "gemma3-270m", "qwen3-0.6")
  /// Downloads the model if needed and initializes it for inference
  Future<void> init(String modelSlug, {
    Function(double)? onDownloadProgress,
    Function(String)? onLog,
  }) async {
    if (_isInitialized && _currentModelSlug == modelSlug) {
      if (onLog != null) onLog("Model already initialized: $modelSlug");
      return;
    }

    _currentModelSlug = modelSlug;
    
    if (onLog != null) onLog("Downloading $modelSlug...");

    // Download model using SDK's built-in download
    await _cactus.downloadModel(
      model: modelSlug,
      downloadProcessCallback: (progress, status, isError) {
        if (isError) {
          print("CactusBrain: Download error - $status");
          if (onLog != null) onLog("Error: $status");
        } else {
          // Only update progress bar, no log spam
          if (onDownloadProgress != null && progress != null) {
            onDownloadProgress(progress);
          }
        }
      },
    );

    if (onLog != null) onLog("Initializing model...");

    // Initialize the downloaded model
    await _cactus.initializeModel(
      params: CactusInitParams(
        model: modelSlug,
        contextSize: 2048,
      ),
    );

    _isInitialized = true;
    if (onLog != null) onLog("Model ready: $modelSlug");
    print("CactusBrain: Model initialized successfully");
  }

  Future<AgentResponse> ask(String imagePath, String uiTree, String mainGoal) async {
    if (!_isInitialized) {
      throw Exception("CactusBrain not initialized. Call init() first.");
    }

    // Construct the prompt using ChatMessage with the image
    final messages = [
      ChatMessage(role: "system", content: PromptStrategy.systemPrompt),
      ChatMessage(
        role: "user",
        content: "Goal: $mainGoal\n\nUI Tree:\n$uiTree",
        images: [imagePath], // ← Pass the screenshot to the vision model!
      ),
    ];

    try {
      final result = await _cactus.generateCompletion(
        messages: messages,
        params: CactusCompletionParams(
          maxTokens: 300,
          stopSequences: ["<|im_end|>", "<end_of_turn>"], // Stop tokens
        ),
      );
      
      if (!result.success) {
        print("CactusBrain: Generation failed");
        return AgentResponse(
          analysis: "Error: Generation failed",
          plan: "none",
          action: "none",
        );
      }

      final responseText = result.response ?? "{}";
      print("CactusBrain: Generated response (${result.tokensPerSecond.toStringAsFixed(1)} tok/s)");
      
      // Aggressive JSON cleaning to handle all edge cases
      String cleanJson = _cleanJsonResponse(responseText);

      return AgentResponse.fromJson(jsonDecode(cleanJson));
    } catch (e, stackTrace) {
      print("CactusBrain: Error during inference: $e");
      print("Stack trace: $stackTrace");
      // Return a default AgentResponse in case of error
      return AgentResponse(analysis: "Error: $e", plan: "none", action: "none");
    }
  }

  /// Aggressively clean the model's response to extract valid JSON
  String _cleanJsonResponse(String raw) {
    String cleaned = raw.trim();
    
    // Remove markdown code blocks
    cleaned = cleaned.replaceAll(RegExp(r'```json\s*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'```\s*'), '');
    
    // Remove stop tokens that sometimes appear despite stopSequences
    cleaned = cleaned.replaceAll('<end_of_turn>', '');
    cleaned = cleaned.replaceAll('<|im_end|>', '');
    cleaned = cleaned.trim();
    
    // Remove trailing commas before closing braces/brackets
    cleaned = cleaned.replaceAll(RegExp(r',(\s*[}\]])'), r'$1');
    
    // Remove all JavaScript-style comments (both // and /* */)
    cleaned = cleaned.replaceAll(RegExp(r'//.*?$', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
    
    // Remove { ... } placeholders
    cleaned = cleaned.replaceAll(RegExp(r'\{\s*\.\.\.\s*\}'), '""');
    
    // Find the first { and last } to extract just the JSON object
    final firstBrace = cleaned.indexOf('{');
    final lastBrace = cleaned.lastIndexOf('}');
    
    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      cleaned = cleaned.substring(firstBrace, lastBrace + 1);
    }
    
    // Only print cleaned JSON if there were changes
    if (cleaned != raw.trim()) {
      print("CactusBrain: Cleaned JSON");
    }
    return cleaned;
  }

  /// Get list of available models from Cactus SDK
  Future<List<CactusModel>> getAvailableModels() async {
    return await _cactus.getModels();
  }

  void dispose() {
    _cactus.unload();
  }
}

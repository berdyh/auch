import 'package:cactus/cactus.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
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
  String? _modelPath;

  Future<void> init(String modelPath) async {
    if (_isInitialized) return;
    _modelPath = modelPath;

    // Initialize with the local model file
    await _cactus.initializeModel(
      params: CactusInitParams(
        model: modelPath,
        contextSize: 2048
      )
    );
    _isInitialized = true;
  }

  Future<AgentResponse> ask(String imagePath, String uiTree, String mainGoal) async {
    if (!_isInitialized) {
      if (_modelPath != null) {
        await init(_modelPath!);
      } else {
        throw Exception("CactusBrain not initialized with model path.");
      }
    }

    final userContent = "GOAL: $mainGoal\n\nUI TREE:\n$uiTree";

    final response = await _cactus.generateCompletion(
      messages: [
        ChatMessage(
          role: "system",
          content: PromptStrategy.systemPrompt
        ),
        ChatMessage(
          role: "user",
          content: userContent,
          images: [imagePath]
        )
      ],
      params: CactusCompletionParams(
        maxTokens: 500,
        temperature: 0.1, // Low temperature for deterministic JSON
      )
    );

    if (!response.success) {
      throw Exception("Cactus inference failed: ${response.response}"); // In failure, response might contain error info?
      // Actually success=false usually means error.
    }

    // Clean up response if it contains markdown code blocks
    String cleanJson = response.response.trim();
    if (cleanJson.startsWith("```json")) {
      cleanJson = cleanJson.replaceAll("```json", "").replaceAll("```", "");
    } else if (cleanJson.startsWith("```")) {
      cleanJson = cleanJson.replaceAll("```", "");
    }

    try {
      final Map<String, dynamic> jsonMap = jsonDecode(cleanJson);
      return AgentResponse.fromJson(jsonMap);
    } catch (e) {
      throw Exception("Failed to parse agent JSON: $cleanJson");
    }
  }

  void dispose() {
    _cactus.unload();
  }
}

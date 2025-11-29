import 'package:cactus/cactus.dart';

void main() {
  CactusLM lm = CactusLM();
  
  // Check ChatMessage
  final msg = ChatMessage(role: "user", content: "Hello");
  
  // Check if we can pass a callback
  lm.downloadModel(
    model: "qwen3-0.6",
    progress: (progress) {}, 
  );
  
  // Check if we can pass a callback
  // lm.downloadModel(
  //   model: "qwen3-0.6",
  //   onProgress: (progress) {}, // Guessing param name
  // );
}

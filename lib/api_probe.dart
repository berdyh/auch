import 'package:cactus/cactus.dart';

/// Small probe to verify the Cactus API surface; not used by the app runtime.
Future<void> main() async {
  final lm = CactusLM();
  await lm.downloadModel(
    model: "qwen3-0.6",
    downloadProcessCallback: (progress, status, isError) {},
  );
  lm.unload();
}

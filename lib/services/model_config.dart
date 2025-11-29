/// Simplified model configuration
/// Maps user-friendly names to Cactus SDK model slugs
class ModelConfig {
  static const Map<String, ModelSlugInfo> availableModels = {
    'Liquid VL - 450M (Vision + Recommended)': ModelSlugInfo(
      slug: 'lfm2-vl-450m',
      description: '~500MB - Can see images!',
      supportsVision: true,
    ),
    'Gemma 3 - 270M (Text Only)': ModelSlugInfo(
      slug: 'gemma3-270m',
      description: '~300MB - Small and fast',
      supportsVision: false,
    ),
    'Qwen 3 - 600M (Text Only)': ModelSlugInfo(
      slug: 'qwen3-0.6',
      description: '~600MB - Good balance',
      supportsVision: false,
    ),
  };
}

class ModelSlugInfo {
  final String slug;
  final String description;
  final bool supportsVision;

  const ModelSlugInfo({
    required this.slug,
    required this.description,
    required this.supportsVision,
  });
}

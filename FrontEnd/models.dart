/// Core data models for the Image Generation Character Consistency Studio.
library models;

enum SeedMode { fixed, random }

enum LoadState { notLoaded, loading, loaded, error }

/// A single generated image (either "base" or "lora" variant).
class GeneratedImage {
  final String variantLabel; // "Base" or "LoRA"
  final int seed;
  final String prompt;
  final DateTime createdAt;
  // In a real app this would hold image bytes / a file path / a URL.
  // Placeholder studios render a deterministic gradient swatch instead.
  final int colorSeed;

  GeneratedImage({
    required this.variantLabel,
    required this.seed,
    required this.prompt,
    required this.colorSeed,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// A matched pair — same prompt & seed, base vs LoRA — the core comparison unit.
class ComparisonPair {
  final int seed;
  final GeneratedImage base;
  final GeneratedImage lora;

  ComparisonPair({required this.seed, required this.base, required this.lora});
}

/// One full "run": a prompt fanned out across several seeds.
class GenerationRun {
  final String id;
  final String prompt;
  final double loraStrength;
  final int resolution;
  final int steps;
  final double guidanceScale;
  final List<ComparisonPair> pairs;
  final DateTime timestamp;

  GenerationRun({
    required this.id,
    required this.prompt,
    required this.loraStrength,
    required this.resolution,
    required this.steps,
    required this.guidanceScale,
    required this.pairs,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Sidebar / pipeline configuration state.
class PipelineSettings {
  String baseModelPath;
  String loraPath;
  LoadState baseModelState;
  LoadState loraState;
  double loraStrength;
  int resolution;
  int inferenceSteps;
  double guidanceScale;
  SeedMode seedMode;
  int fixedSeed;
  int numSeeds;

  PipelineSettings({
    this.baseModelPath = '',
    this.loraPath = '',
    this.baseModelState = LoadState.notLoaded,
    this.loraState = LoadState.notLoaded,
    this.loraStrength = 0.8,
    this.resolution = 1024,
    this.inferenceSteps = 28,
    this.guidanceScale = 4.5,
    this.seedMode = SeedMode.random,
    this.fixedSeed = 42,
    this.numSeeds = 3,
  });

  bool get readyToGenerate =>
      baseModelState == LoadState.loaded && loraState == LoadState.loaded;
}
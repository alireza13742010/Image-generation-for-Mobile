/// A single saved generation: the prompt/settings used and where its
/// image file lives on disk.
class HistoryEntry {
  final String id;
  final String prompt;
  final int steps;
  final double guidanceScale;
  final String imageFileName; // stored relative to the history directory
  final DateTime createdAt;

  HistoryEntry({
    required this.id,
    required this.prompt,
    required this.steps,
    required this.guidanceScale,
    required this.imageFileName,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'prompt': prompt,
        'steps': steps,
        'guidanceScale': guidanceScale,
        'imageFileName': imageFileName,
        'createdAt': createdAt.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        id: json['id'] as String,
        prompt: json['prompt'] as String,
        steps: json['steps'] as int,
        guidanceScale: (json['guidanceScale'] as num).toDouble(),
        imageFileName: json['imageFileName'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
class AiInsight {
  final String id;
  final String workspaceId;
  final String title;
  final String summary;
  final String aiRecommendation;
  final String type; // e.g., 'opportunity', 'threat', 'trend'
  final String severity; // e.g., 'high', 'medium', 'low'
  final DateTime createdAt;
  final double confidenceScore;
  final List<String> sources;

  const AiInsight({
    required this.id,
    required this.workspaceId,
    required this.title,
    required this.summary,
    required this.aiRecommendation,
    required this.type,
    required this.severity,
    required this.createdAt,
    required this.confidenceScore,
    required this.sources,
  });

  factory AiInsight.fromJson(Map<String, dynamic> json) {
    return AiInsight(
      id: json['id'] as String,
      workspaceId: json['workspace_id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      aiRecommendation: json['ai_recommendation'] as String,
      type: json['type'] as String,
      severity: json['severity'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.95,
      sources: (json['sources'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

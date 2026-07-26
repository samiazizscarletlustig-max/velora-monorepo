class StrategyConnection {
  final String id;
  final String sourceNodeId;
  final String targetNodeId;
  final String? label;

  const StrategyConnection({
    required this.id,
    required this.sourceNodeId,
    required this.targetNodeId,
    this.label,
  });
}

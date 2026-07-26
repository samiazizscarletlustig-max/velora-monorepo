class StrategyTemplate {
  final String id;
  final String name;
  final String description;
  final String iconAsset; // or just use IconData for prototype

  const StrategyTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.iconAsset,
  });
}

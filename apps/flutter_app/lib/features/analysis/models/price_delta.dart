class PriceDelta {
  final String id;
  final String competitorName;
  final String productName;
  final double oldPrice;
  final double newPrice;
  final double deltaPercentage;
  final DateTime lastUpdatedAt;
  final String sourceUrl;
  final bool isIncrease;

  const PriceDelta({
    required this.id,
    required this.competitorName,
    required this.productName,
    required this.oldPrice,
    required this.newPrice,
    required this.deltaPercentage,
    required this.lastUpdatedAt,
    required this.sourceUrl,
    required this.isIncrease,
  });
}

class DataPoint {
  final DateTime date;
  final double value;

  const DataPoint(this.date, this.value);
}

class CompetitorMetric {
  final String id;
  final String name;
  final double healthScore;
  final double marketShare;
  final String pricingTrend; // 'increasing', 'decreasing', 'stable'
  final String threatLevel; // 'high', 'medium', 'low'
  final List<DataPoint> historicalMarketShare;

  const CompetitorMetric({
    required this.id,
    required this.name,
    required this.healthScore,
    required this.marketShare,
    required this.pricingTrend,
    required this.threatLevel,
    required this.historicalMarketShare,
  });
}

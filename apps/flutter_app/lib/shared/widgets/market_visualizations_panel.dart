import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'analytics_chart.dart';

/// لوحة Market Visualizations: ترسم بيانات chart_bundle القادمة من محرك Velora.
class MarketVisualizationsPanel extends StatelessWidget {
  final Map<String, dynamic> data;
  const MarketVisualizationsPanel({super.key, required this.data});

  static const Color _accent = Color(0xFF8B5CF6);

  List get _dist => (data['price_distribution'] as List?) ?? [];
  Map get _seg => (data['segments'] as Map?) ?? {};
  List get _cats => (data['categories'] as List?) ?? [];
  Map get _sig => (data['signals'] as Map?) ?? {};
  List get _hist => (data['price_history'] as List?) ?? [];
  Map get _head => (data['headlines'] as Map?) ?? {};

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Market Visualizations',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        _headlines(),
        const SizedBox(height: 20),
        _section('Price Distribution', _distBar()),
        const SizedBox(height: 20),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _section('Segments', _segmentsDonut())),
          const SizedBox(width: 16),
          Expanded(child: _section('Signals', _signalsBar())),
        ]),
        const SizedBox(height: 20),
        _section('Top Categories (avg price)', _catsBar()),
        const SizedBox(height: 20),
        if (_hist.length >= 2) _section('Avg Price Over Time', _historyLine()),
      ]),
    );
  }

  Widget _headlines() {
    final avg = (_head['avg'] as num? ?? 0).toDouble();
    final med = (_head['median'] as num? ?? 0).toDouble();
    final vuln = (_head['vulnerability'] as num? ?? 0).toDouble();
    return Row(children: [
      _stat('Avg Price', '\$${avg.toStringAsFixed(2)}'),
      const SizedBox(width: 12),
      _stat('Median', '\$${med.toStringAsFixed(2)}'),
      const SizedBox(width: 12),
      _stat('Vulnerability', '${vuln.toStringAsFixed(0)}/100'),
    ]);
  }

  Widget _stat(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(children: [
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _accent)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5))),
          ]),
        ),
      );

  Widget _section(String title, Widget chart) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SizedBox(height: 180, child: chart),
        ],
      );

  Widget _distBar() {
    if (_dist.isEmpty) return const SizedBox.shrink();
    double maxY = 0;
    for (final e in _dist) {
      final v = (e['count'] as num).toDouble();
      if (v > maxY) maxY = v;
    }
    return BarChart(BarChartData(
      maxY: maxY * 1.2,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      barGroups: [
        for (int i = 0; i < _dist.length; i++)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(toY: (_dist[i]['count'] as num).toDouble(), color: _accent, width: 22, borderRadius: BorderRadius.circular(4)),
          ]),
      ],
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26,
            getTitlesWidget: (v, m) {
              final i = v.toInt();
              if (i < 0 || i >= _dist.length) return const SizedBox.shrink();
              return Text((_dist[i]['range'] ?? '').toString(), style: const TextStyle(fontSize: 8, color: Colors.white38));
            })),
      ),
    ));
  }

  Widget _segmentsDonut() {
    final items = [
      {'n': 'Budget', 'v': (_seg['budget'] as num? ?? 0).toDouble(), 'c': Colors.green},
      {'n': 'Mid', 'v': (_seg['mid'] as num? ?? 0).toDouble(), 'c': _accent},
      {'n': 'Premium', 'v': (_seg['premium'] as num? ?? 0).toDouble(), 'c': Colors.orange},
    ].where((e) => e['v'] as double > 0).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return PieChart(PieChartData(
      sectionsSpace: 2,
      centerSpaceRadius: 28,
      sections: [
        for (final e in items)
          PieChartSectionData(
            value: e['v'] as double,
            title: '${e['n']}\n${(e['v'] as double).toStringAsFixed(0)}%',
            color: e['c'] as Color,
            radius: 55,
            titleStyle: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
          ),
      ],
    ));
  }

  Widget _signalsBar() {
    final keys = ['velocity', 'scarcity', 'freshness', 'promo'];
    return BarChart(BarChartData(
      maxY: 100,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      barGroups: [
        for (int i = 0; i < keys.length; i++)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(toY: (_sig[keys[i]] as num? ?? 0).toDouble(), color: Colors.cyan, width: 18, borderRadius: BorderRadius.circular(4)),
          ]),
      ],
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22,
            getTitlesWidget: (v, m) {
              final i = v.toInt();
              if (i < 0 || i >= keys.length) return const SizedBox.shrink();
              return Text(keys[i], style: const TextStyle(fontSize: 8, color: Colors.white38));
            })),
      ),
    ));
  }

  Widget _catsBar() {
    if (_cats.isEmpty) return const SizedBox.shrink();
    double maxY = 0;
    for (final e in _cats) {
      final v = (e['avg_price'] as num).toDouble();
      if (v > maxY) maxY = v;
    }
    return BarChart(BarChartData(
      maxY: maxY * 1.2,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      barGroups: [
        for (int i = 0; i < _cats.length; i++)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(toY: (_cats[i]['avg_price'] as num).toDouble(), color: Colors.amber, width: 20, borderRadius: BorderRadius.circular(4)),
          ]),
      ],
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22,
            getTitlesWidget: (v, m) {
              final i = v.toInt();
              if (i < 0 || i >= _cats.length) return const SizedBox.shrink();
              return Text((_cats[i]['name'] ?? '').toString(), style: const TextStyle(fontSize: 9, color: Colors.white38));
            })),
      ),
    ));
  }

  // منحنى السعر عبر الزمن باستخدام AnalyticsChart الموجود لديك
  Widget _historyLine() {
    final points = <ChartDataPoint>[];
    for (int i = 0; i < _hist.length; i++) {
      final avg = (_hist[i]['avg'] as num).toDouble();
      final date = (_hist[i]['date'] ?? '').toString();
      points.add(ChartDataPoint(x: i.toDouble(), y: avg, xLabel: date, yLabel: '\$${avg.toStringAsFixed(2)}'));
    }
    return AnalyticsChart(
      series: [ChartSeries(data: points, color: _accent, name: 'Avg Price')],
      height: 180,
    );
  }
}
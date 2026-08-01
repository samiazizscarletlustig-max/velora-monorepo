import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../shared/widgets/velora_card.dart';
import '../providers/analytics_providers.dart';
import '../../data/analytics_repository.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statsAsync = ref.watch(analyticsStatsProvider);
    final distributionAsync = ref.watch(insightsDistributionProvider);
    final timelineAsync = ref.watch(insightsTimelineProvider);
    final topCompetitorsAsync = ref.watch(topCompetitorsProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ═══ Header ═══
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'analytics.title'.tr(),
                      style: theme.textTheme.displayLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'analytics.subtitle'.tr(),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () {
                    ref.read(refreshAnalyticsProvider)(ref);
                  },
                  icon: const Icon(Icons.refresh),
                  tooltip: 'analytics.refresh'.tr(),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ═══ Stats Grid ═══
            statsAsync.when(
              data: (stats) => _StatsGrid(stats: stats),
              loading: () => const _StatsGridLoading(),
              error: (error, _) => _ErrorCard(error: error.toString()),
            ),
            const SizedBox(height: 32),

            // ═══ Charts Row (Pie + Line) ═══
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 1000;
                
                if (isDesktop) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: distributionAsync.when(
                          data: (slices) => _PieChartCard(slices: slices),
                          loading: () => const _ChartLoading(),
                          error: (e, _) => _ErrorCard(error: e.toString()),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: timelineAsync.when(
                          data: (points) => _LineChartCard(points: points),
                          loading: () => const _ChartLoading(),
                          error: (e, _) => _ErrorCard(error: e.toString()),
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      distributionAsync.when(
                        data: (slices) => _PieChartCard(slices: slices),
                        loading: () => const _ChartLoading(),
                        error: (e, _) => _ErrorCard(error: e.toString()),
                      ),
                      const SizedBox(height: 24),
                      timelineAsync.when(
                        data: (points) => _LineChartCard(points: points),
                        loading: () => const _ChartLoading(),
                        error: (e, _) => _ErrorCard(error: e.toString()),
                      ),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 32),

            // ═══ Bar Chart (Top Competitors) ═══
            topCompetitorsAsync.when(
              data: (data) => _BarChartCard(data: data),
              loading: () => const _ChartLoading(),
              error: (error, _) => _ErrorCard(error: error.toString()),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Stats Grid Widget
// ═══════════════════════════════════════════

class _StatsGrid extends StatelessWidget {
  final AnalyticsStats stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        final crossAxisCount = isDesktop ? 4 : 2;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: isDesktop ? 2.2 : 1.6,
          children: [
            _StatCard(
              icon: Icons.storefront_outlined,
              title: 'analytics.competitors'.tr(),
              value: stats.totalCompetitors.toString(),
              color: const Color(0xFF4F46E5),
            ),
            _StatCard(
              icon: Icons.shopping_bag_outlined,
              title: 'analytics.products'.tr(),
              value: stats.totalProducts.toString(),
              color: const Color(0xFF10B981),
            ),
            _StatCard(
              icon: Icons.lightbulb_outline,
              title: 'analytics.insights'.tr(),
              value: stats.totalInsights.toString(),
              color: const Color(0xFFF59E0B),
            ),
            _StatCard(
              icon: Icons.analytics_outlined,
              title: 'analytics.avg_per_competitor'.tr(),
              value: stats.avgProductsPerCompetitor.toString(),
              color: const Color(0xFF3B82F6),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return VeloraCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.secondary,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// 🥧 Pie Chart Widget (Insights Distribution)
// ═══════════════════════════════════════════

class _PieChartCard extends StatelessWidget {
  final List<PieSlice> slices;
  const _PieChartCard({required this.slices});

  Color _hexToColor(String hex) {
    return Color(int.parse('0xFF$hex'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return VeloraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'analytics.insights_distribution'.tr(),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'analytics.by_severity'.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 24),

          if (slices.isEmpty)
            const _ChartEmptyState(icon: Icons.pie_chart_outline)
          else ...[
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: _buildSections(),
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: slices.map((slice) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _hexToColor(slice.colorHex),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${slice.label}: ${slice.value.toInt()}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildSections() {
    final total = slices.fold<double>(0, (sum, s) => sum + s.value);
    
    return slices.map((slice) {
      final percentage = (slice.value / total * 100).toInt();
      return PieChartSectionData(
        value: slice.value,
        color: _hexToColor(slice.colorHex),
        title: '$percentage%',
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        radius: 50,
      );
    }).toList();
  }
}

// ═══════════════════════════════════════════
// 📈 Line Chart Widget (Timeline)
// ═══════════════════════════════════════════

class _LineChartCard extends StatelessWidget {
  final List<ChartDataPoint> points;
  const _LineChartCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return VeloraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'analytics.insights_timeline'.tr(),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'analytics.last_30_days'.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 24),

          if (points.isEmpty)
            const _ChartEmptyState(icon: Icons.show_chart)
          else
            SizedBox(
              height: 220,
              child: LineChart(
                _buildLineChartData(),
                // ✅ تم إزالة duration - غير مدعوم في fl_chart 0.68+
              ),
            ),
        ],
      ),
    );
  }

  LineChartData _buildLineChartData() {
    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: points.isEmpty ? 1 : (points.length / 4).ceil().toDouble(),
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= points.length) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  DateFormat('d/M').format(points[index].date),
                  style: const TextStyle(fontSize: 10),
                ),
              );
            },
          ),
        ),
        leftTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: points.isEmpty ? 1 : (points.length - 1).toDouble(),
      minY: 0,
      maxY: points.isEmpty 
          ? 1 
          : points.map((p) => p.value).reduce((a, b) => a > b ? a : b) * 1.2,
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (spot) => const Color(0xFF1F2937).withOpacity(0.9),
          getTooltipItems: (spots) {
            return spots.map((spot) {
              final index = spot.x.toInt();
              if (index < 0 || index >= points.length) return null;
              return LineTooltipItem(
                '${DateFormat('MMM d').format(points[index].date)}\n',
                const TextStyle(color: Colors.white, fontSize: 11),
                children: [
                  TextSpan(
                    text: '${points[index].value.toInt()} insights',
                    style: const TextStyle(
                      color: Color(0xFF4F46E5),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              );
            }).toList();
          },
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: points.asMap().entries.map((entry) {
            return FlSpot(entry.key.toDouble(), entry.value.value);
          }).toList(),
          isCurved: true,
          color: const Color(0xFF4F46E5),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, bar, index) {
              return FlDotCirclePainter(
                radius: 4,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: const Color(0xFF4F46E5),
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            color: const Color(0xFF4F46E5).withOpacity(0.1),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════
// 📊 Bar Chart Widget (Top Competitors)
// ═══════════════════════════════════════════

class _BarChartCard extends StatelessWidget {
  final List<ChartDataPoint> data;
  const _BarChartCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return VeloraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'analytics.top_competitors'.tr(),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'analytics.by_products_count'.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 24),

          if (data.isEmpty)
            const _ChartEmptyState(icon: Icons.bar_chart)
          else
            SizedBox(
              height: 250,
              child: BarChart(
                _buildBarChartData(),
                // ✅ تم إزالة duration - غير مدعوم في fl_chart 0.68+
              ),
            ),
        ],
      ),
    );
  }

  BarChartData _buildBarChartData() {
    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: data.isEmpty 
          ? 1 
          : data.map((d) => d.value).reduce((a, b) => a > b ? a : b) * 1.2,
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (group) => const Color(0xFF1F2937).withOpacity(0.9),
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final label = data[group.x.toInt()].label ?? 'Unknown';
            return BarTooltipItem(
              '$label\n',
              const TextStyle(color: Colors.white, fontSize: 11),
              children: [
                TextSpan(
                  text: '${rod.toY.toInt()} products',
                  style: const TextStyle(
                    color: Color(0xFF4F46E5),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= data.length) {
                return const SizedBox.shrink();
              }
              final label = data[index].label ?? 'Unknown';
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  label.length > 10 ? '${label.substring(0, 10)}...' : label,
                  style: const TextStyle(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
        ),
        leftTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      barGroups: data.asMap().entries.map((entry) {
        return BarChartGroupData(
          x: entry.key,
          barRods: [
            BarChartRodData(
              toY: entry.value.value,
              color: const Color(0xFF4F46E5),
              width: 20,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════
// Empty State & Loading Widgets
// ═══════════════════════════════════════════

class _ChartEmptyState extends StatelessWidget {
  final IconData icon;
  const _ChartEmptyState({required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 56,
              color: theme.colorScheme.secondary.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'analytics.no_data'.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'analytics.run_scraper'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.secondary.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartLoading extends StatelessWidget {
  const _ChartLoading();

  @override
  Widget build(BuildContext context) {
    return VeloraCard(
      child: SizedBox(
        height: 300,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _StatsGridLoading extends StatelessWidget {
  const _StatsGridLoading();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        final crossAxisCount = isDesktop ? 4 : 2;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: isDesktop ? 2.2 : 1.6,
          children: List.generate(
            4,
            (_) => VeloraCard(
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String error;
  const _ErrorCard({required this.error});

  @override
  Widget build(BuildContext context) {
    return VeloraCard(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Error: $error',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
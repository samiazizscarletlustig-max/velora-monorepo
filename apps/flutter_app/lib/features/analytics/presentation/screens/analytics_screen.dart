import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_colors.dart';
import '../../../../core/widgets/premium_widgets.dart';
import '../../../../core/extensions/widget_extensions.dart';
import '../providers/analytics_providers.dart';
import '../../data/analytics_repository.dart';

// ═══════════════════════════════════════════════════════════
// 📊 ANALYTICS SCREEN — PERFECTION EDITION (100% FIXED)
// ═══════════════════════════════════════════════════════════
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(analyticsStatsProvider);
    final distributionAsync = ref.watch(insightsDistributionProvider);
    final timelineAsync = ref.watch(insightsTimelineProvider);
    final topCompetitorsAsync = ref.watch(topCompetitorsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedGradientBackground(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _HeroHeader(
                onRefresh: () {
                  ref.read(refreshAnalyticsProvider)(ref);
                },
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              sliver: SliverToBoxAdapter(
                child: statsAsync.when(
                  data: (stats) => _PremiumStatsGrid(stats: stats),
                  loading: () => const _StatsGridLoading(),
                  error: (error, _) => _ErrorState(
                    error: error.toString(),
                    onRetry: () => ref.invalidate(analyticsStatsProvider),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
              sliver: SliverToBoxAdapter(
                child: LayoutBuilder(builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 1000;
                  if (isDesktop) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: distributionAsync.when(
                            data: (slices) => _PieChartCard(slices: slices).stagger(2),
                            loading: () => const _ChartLoading(),
                            error: (e, _) => _ErrorState(
                              error: e.toString(),
                              onRetry: () => ref.invalidate(insightsDistributionProvider),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: timelineAsync.when(
                            data: (points) => _LineChartCard(points: points).stagger(3),
                            loading: () => const _ChartLoading(),
                            error: (e, _) => _ErrorState(
                              error: e.toString(),
                              onRetry: () => ref.invalidate(insightsTimelineProvider),
                            ),
                          ),
                        ),
                      ],
                    );
                  } else {
                    return Column(children: [
                      distributionAsync.when(
                        data: (slices) => _PieChartCard(slices: slices).stagger(2),
                        loading: () => const _ChartLoading(),
                        error: (e, _) => _ErrorState(
                          error: e.toString(),
                          onRetry: () => ref.invalidate(insightsDistributionProvider),
                        ),
                      ),
                      const SizedBox(height: 24),
                      timelineAsync.when(
                        data: (points) => _LineChartCard(points: points).stagger(3),
                        loading: () => const _ChartLoading(),
                        error: (e, _) => _ErrorState(
                          error: e.toString(),
                          onRetry: () => ref.invalidate(insightsTimelineProvider),
                        ),
                      ),
                    ]);
                  }
                }),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 80),
              sliver: SliverToBoxAdapter(
                child: topCompetitorsAsync.when(
                  data: (data) => _BarChartCard(data: data).stagger(4),
                  loading: () => const _ChartLoading(),
                  error: (error, _) => _ErrorState(
                    error: error.toString(),
                    onRetry: () => ref.invalidate(topCompetitorsProvider),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🌅 HERO HEADER
// ═══════════════════════════════════════════════════════════
class _HeroHeader extends StatelessWidget {
  final VoidCallback onRefresh;
  const _HeroHeader({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.darkAccent.withOpacity(0.15), AppColors.purple.withOpacity(0.08), Colors.transparent]
              : [AppColors.lightAccent.withOpacity(0.12), AppColors.purple.withOpacity(0.06), Colors.transparent],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.chartGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: AppColors.darkAccent.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('analytics.title'.tr(), style: GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.8, color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary)),
                  const SizedBox(height: 2),
                  Text('analytics.subtitle'.tr(), style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary)),
                ]),
              ),
            ]),
          ),
          Container(
            height: 44,
            decoration: BoxDecoration(color: isDark ? AppColors.darkSurface : AppColors.lightSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
            child: IconButton(onPressed: onRefresh, icon: Icon(Icons.refresh_rounded, color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary, size: 20), tooltip: 'analytics.refresh'.tr()),
          ),
        ]),
      ]),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1);
  }
}

// ═══════════════════════════════════════════════════════════
// 📊 PREMIUM STATS GRID
// ═══════════════════════════════════════════════════════════
class _PremiumStatsGrid extends StatelessWidget {
  final AnalyticsStats stats;
  const _PremiumStatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth > 900;
      final isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 900;
      final cards = [
        _StatCardData(icon: Icons.storefront_rounded, label: 'analytics.competitors'.tr(), value: stats.totalCompetitors, color: AppColors.darkAccent, gradient: AppColors.primaryGradient, sparkline: const [1, 1, 2, 2, 2, 3, 3, 4, 4, 5]),
        _StatCardData(icon: Icons.shopping_bag_rounded, label: 'analytics.products'.tr(), value: stats.totalProducts, color: AppColors.success, gradient: AppColors.successGradient, sparkline: const [100, 120, 140, 160, 180, 200, 220, 240, 250, 260]),
        _StatCardData(icon: Icons.auto_awesome_rounded, label: 'analytics.insights'.tr(), value: stats.totalInsights, color: AppColors.warning, gradient: AppColors.warningGradient, sparkline: const [1, 2, 2, 3, 3, 4, 5, 6, 7, 8]),
        _StatCardData(icon: Icons.trending_up_rounded, label: 'analytics.avg_per_competitor'.tr(), value: stats.avgProductsPerCompetitor.round(), color: AppColors.info, gradient: AppColors.infoGradient, sparkline: const [40, 42, 45, 48, 50, 52, 55, 58, 60, 62], suffix: '/store'),
      ];

      if (isDesktop) {
        return Row(children: cards.asMap().entries.map((e) => Expanded(child: Padding(padding: EdgeInsets.only(left: e.key == 0 ? 0 : 16), child: _AnimatedStatCard(data: e.value).stagger(e.key)))).toList());
      } else if (isTablet) {
        return Column(children: [
          Row(children: [Expanded(child: _AnimatedStatCard(data: cards[0]).stagger(0)), const SizedBox(width: 16), Expanded(child: _AnimatedStatCard(data: cards[1]).stagger(1))]),
          const SizedBox(height: 16),
          Row(children: [Expanded(child: _AnimatedStatCard(data: cards[2]).stagger(2)), const SizedBox(width: 16), Expanded(child: _AnimatedStatCard(data: cards[3]).stagger(3))]),
        ]);
      } else {
        return Column(children: cards.asMap().entries.map((e) => Padding(padding: EdgeInsets.only(top: e.key == 0 ? 0 : 12), child: _AnimatedStatCard(data: e.value).stagger(e.key))).toList());
      }
    });
  }
}

class _StatCardData {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final Gradient gradient;
  final List<int> sparkline;
  final String? suffix;
  const _StatCardData({required this.icon, required this.label, required this.value, required this.color, required this.gradient, required this.sparkline, this.suffix});
}

class _AnimatedStatCard extends StatelessWidget {
  final _StatCardData data;
  const _AnimatedStatCard({required this.data});

  String _compact(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 10000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Semantics(
        label: '${data.label}: ${data.value}',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(gradient: data.gradient, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: data.color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]), child: Icon(data.icon, color: Colors.white, size: 22)),
            _Sparkline(data: data.sparkline, color: data.color),
          ]),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: data.value),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Text(_compact(v), style: GoogleFonts.sora(fontSize: 32, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary, letterSpacing: -1, height: 1, fontFeatures: const [FontFeature.tabularFigures()])),
            ),
            if (data.suffix != null) ...[
              const SizedBox(width: 4),
              Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(data.suffix!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary))),
            ],
          ]),
          const SizedBox(height: 6),
          Text(data.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary, letterSpacing: 0.2)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 📈 SPARKLINE
// ═══════════════════════════════════════════════════════════
class _Sparkline extends StatelessWidget {
  final List<int> data;
  final Color color;
  const _Sparkline({required this.data, required this.color});

  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(60, 28), painter: _SparklinePainter(data: data, color: color));
}

class _SparklinePainter extends CustomPainter {
  final List<int> data;
  final Color color;
  _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxVal = data.reduce(math.max).toDouble();
    final minVal = data.reduce(math.min).toDouble();
    final range = maxVal - minVal == 0 ? 1.0 : maxVal - minVal;
    final path = Path();
    final stepX = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final normalizedY = (data[i] - minVal) / range;
      final y = size.height - (normalizedY * size.height * 0.8) - (size.height * 0.1);
      if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
    }

    final fillPath = Path.from(path)..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(fillPath, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withOpacity(0.25), color.withOpacity(0.0)]).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round);

    final lastX = (data.length - 1) * stepX;
    final lastY = size.height - (((data.last - minVal) / range) * size.height * 0.8) - (size.height * 0.1);
    canvas.drawCircle(Offset(lastX, lastY), 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) => old.data != data || old.color != color;
}

// ═══════════════════════════════════════════════════════════
// 🥧 PREMIUM PIE CHART — 100% FIXED FOR FL_CHART 0.68.0
// ═══════════════════════════════════════════════════════════
class _PieChartCard extends StatelessWidget {
  final List<PieSlice> slices;
  const _PieChartCard({required this.slices});

  Color _hexToColor(String hex) {
    try { return Color(int.parse('0xFF$hex')); } catch (_) { return AppColors.darkAccent; }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double total = slices.fold<double>(0.0, (double sum, PieSlice s) => sum + s.value);

    return GlassCard(
      padding: const EdgeInsets.all(24),
      animate: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.purple.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.pie_chart_rounded, color: Color(0xFF8B5CF6), size: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('analytics.insights_distribution'.tr(), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2)),
              const SizedBox(height: 2),
              Text('analytics.by_severity'.tr(), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary)),
            ]),
          ),
          if (slices.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppColors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.purple.withOpacity(0.3))),
              child: Text(total.toInt().toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6))),
            ),
        ]),
        const SizedBox(height: 24),
        if (slices.isEmpty)
          const _ChartEmptyState(icon: Icons.pie_chart_outline_rounded)
        else ...[
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
                  builder: (context, progress, _) => PieChart(
                    PieChartData(
                      sections: _buildSections(progress),
                      centerSpaceRadius: 55,
                      sectionsSpace: 3,
                      pieTouchData: PieTouchData(touchCallback: (event, response) {}),
                    ),
                  ),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(total.toInt().toString(), style: GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary, letterSpacing: -1)),
                  const SizedBox(height: 2),
                  Text('Total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary, letterSpacing: 0.3)),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: slices.asMap().entries.map((MapEntry<int, PieSlice> entry) {
              final PieSlice slice = entry.value;
              final double percentage = total == 0.0 ? 0.0 : (slice.value / total * 100.0).toDouble();
              return _LegendItem(
                color: _hexToColor(slice.colorHex),
                label: slice.label,
                value: slice.value.toInt(),
                percentage: percentage,
              ).animate(delay: Duration(milliseconds: 100 * entry.key)).fadeIn().slideX(begin: 0.1, end: 0);
            }).toList(),
          ),
        ],
      ]),
    );
  }

  // ✅ 100% FIXED: Explicit types and removed unsupported parameter
  List<PieChartSectionData> _buildSections(double progress) {
    final double total = slices.fold<double>(0.0, (double sum, PieSlice s) => sum + s.value);
    if (total == 0.0) return <PieChartSectionData>[];

    return slices.map<PieChartSectionData>((PieSlice slice) {
      final double percentage = (slice.value / total * 100.0).toDouble();
      final Color color = _hexToColor(slice.colorHex);
      
      return PieChartSectionData(
        value: slice.value * progress,
        color: color,
        title: '',
        radius: 32,
        badgeWidget: percentage > 12.0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Text('${percentage.toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
              )
            : null,
      );
    }).toList();
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  final double percentage;
  const _LegendItem({required this.color, required this.label, required this.value, required this.percentage});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3), boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 4)])),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary)),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
        child: Text('$value (${percentage.toInt()}%)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color, fontFeatures: const [FontFeature.tabularFigures()])),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════
// 📈 PREMIUM LINE CHART
// ═══════════════════════════════════════════════════════════
class _LineChartCard extends StatelessWidget {
  final List<ChartDataPoint> points;
  const _LineChartCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      padding: const EdgeInsets.all(24),
      animate: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.info.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.show_chart_rounded, color: AppColors.info, size: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('analytics.insights_timeline'.tr(), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2)),
              const SizedBox(height: 2),
              Text('analytics.last_30_days'.tr(), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary)),
            ]),
          ),
          if (points.isNotEmpty) _TrendIndicator(points: points),
        ]),
        const SizedBox(height: 24),
        if (points.isEmpty)
          const _ChartEmptyState(icon: Icons.show_chart_rounded)
        else
          SizedBox(
            height: 220,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, progress, _) => LineChart(_buildLineChartData(isDark, progress)),
            ),
          ),
      ]),
    );
  }

  LineChartData _buildLineChartData(bool isDark, double progress) {
    final spots = points.asMap().entries.map((entry) => FlSpot(entry.key.toDouble(), entry.value.value * progress)).toList();
    final maxY = points.isEmpty ? 1.0 : points.map((p) => p.value).reduce((a, b) => a > b ? a : b) * 1.2;

    return LineChartData(
      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY / 4, getDrawingHorizontalLine: (value) => FlLine(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, strokeWidth: 1, dashArray: [4, 4])),
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
              if (index < 0 || index >= points.length) return const SizedBox.shrink();
              return Padding(padding: const EdgeInsets.only(top: 8), child: Text(DateFormat('d/M').format(points[index].date), style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary)));
            },
          ),
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: points.isEmpty ? 1 : (points.length - 1).toDouble(),
      minY: 0,
      maxY: maxY,
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (spot) => (isDark ? AppColors.darkSurface : AppColors.lightPrimary).withOpacity(0.95),
          tooltipRoundedRadius: 10,
          tooltipBorder: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          getTooltipItems: (spots) {
            return spots.map((spot) {
              final index = spot.x.toInt();
              if (index < 0 || index >= points.length) return null;
              return LineTooltipItem(
                DateFormat('MMM d').format(points[index].date),
                TextStyle(color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary, fontSize: 11),
                children: [TextSpan(text: '\n${points[index].value.toInt()} insights', style: const TextStyle(color: AppColors.darkAccent, fontWeight: FontWeight.w700, fontSize: 14))],
              );
            }).toList();
          },
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.3,
          color: AppColors.darkAccent,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(radius: 4, color: isDark ? AppColors.darkSurface : AppColors.lightSurface, strokeWidth: 2, strokeColor: AppColors.darkAccent),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.darkAccent.withOpacity(0.25), AppColors.darkAccent.withOpacity(0.0)]),
          ),
        ),
      ],
    );
  }
}

class _TrendIndicator extends StatelessWidget {
  final List<ChartDataPoint> points;
  const _TrendIndicator({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox.shrink();
    final recent = points.takeLast(3).map((p) => p.value).toList();
    final older = points.takeLast(6).take(3).map((p) => p.value).toList();
    if (recent.isEmpty || older.isEmpty) return const SizedBox.shrink();

    final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
    final olderAvg = older.reduce((a, b) => a + b) / older.length;
    if (olderAvg == 0) return const SizedBox.shrink();

    final change = ((recentAvg - olderAvg) / olderAvg * 100).round();
    final isUp = change >= 0;
    final color = isUp ? AppColors.success : AppColors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: color, size: 14),
        const SizedBox(width: 4),
        Text('${isUp ? '+' : ''}$change%', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    );
  }
}

extension _TakeLast<T> on Iterable<T> {
  Iterable<T> takeLast(int n) {
    final list = toList();
    return list.length <= n ? list : list.sublist(list.length - n);
  }
}

// ═══════════════════════════════════════════════════════════
// 📊 PREMIUM BAR CHART
// ═══════════════════════════════════════════════════════════
class _BarChartCard extends StatelessWidget {
  final List<ChartDataPoint> data;
  const _BarChartCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      padding: const EdgeInsets.all(24),
      animate: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.bar_chart_rounded, color: AppColors.success, size: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('analytics.top_competitors'.tr(), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2)),
              const SizedBox(height: 2),
              Text('analytics.by_products_count'.tr(), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary)),
            ]),
          ),
          if (data.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.success.withOpacity(0.3))),
              child: Text('${data.length} competitors', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success)),
            ),
        ]),
        const SizedBox(height: 24),
        if (data.isEmpty)
          const _ChartEmptyState(icon: Icons.bar_chart_rounded)
        else
          SizedBox(
            height: 280,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, progress, _) => BarChart(_buildBarChartData(isDark, progress)),
            ),
          ),
      ]),
    );
  }

  BarChartData _buildBarChartData(bool isDark, double progress) {
    final maxY = data.isEmpty ? 1.0 : data.map((d) => d.value).reduce((a, b) => a > b ? a : b) * 1.2;
    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY,
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (group) => (isDark ? AppColors.darkSurface : AppColors.lightPrimary).withOpacity(0.95),
          tooltipRoundedRadius: 10,
          tooltipBorder: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final index = group.x.toInt();
            if (index < 0 || index >= data.length) return null;
            final label = data[index].label ?? 'Unknown';
            return BarTooltipItem(
              label,
              TextStyle(color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary, fontSize: 11),
              children: [TextSpan(text: '\n${rod.toY.toInt()} products', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 14))],
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
            reservedSize: 50,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= data.length) return const SizedBox.shrink();
              final label = data[index].label ?? 'Unknown';
              final display = label.length > 10 ? '${label.substring(0, 10)}...' : label;
              return Padding(padding: const EdgeInsets.only(top: 12), child: Text(display, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary, fontWeight: FontWeight.w500), textAlign: TextAlign.center));
            },
          ),
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY / 4, getDrawingHorizontalLine: (value) => FlLine(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, strokeWidth: 1, dashArray: [4, 4])),
      borderData: FlBorderData(show: false),
      barGroups: data.asMap().entries.map((entry) {
        return BarChartGroupData(
          x: entry.key,
          barRods: [BarChartRodData(toY: entry.value.value * progress, gradient: const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xFF10B981), Color(0xFF34D399)]), width: 28, borderRadius: const BorderRadius.vertical(top: Radius.circular(8)))],
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🕳️ EMPTY & LOADING STATES
// ═══════════════════════════════════════════════════════════
class _ChartEmptyState extends StatelessWidget {
  final IconData icon;
  const _ChartEmptyState({required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 220,
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.darkAccent.withOpacity(0.15), AppColors.purple.withOpacity(0.1)]), shape: BoxShape.circle), child: Icon(icon, size: 40, color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary)),
          const SizedBox(height: 16),
          Text('analytics.no_data'.tr(), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('analytics.run_scraper'.tr(), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary)),
        ]),
      ),
    );
  }
}

class _ChartLoading extends StatelessWidget {
  const _ChartLoading();
  @override
  Widget build(BuildContext context) => ShimmerLoading(width: double.infinity, height: 380, borderRadius: 20);
}

class _StatsGridLoading extends StatelessWidget {
  const _StatsGridLoading();
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth > 900;
      final isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 900;
      final card = SizedBox(height: 140, child: ShimmerLoading(width: double.infinity, height: double.infinity, borderRadius: 20));
      if (isDesktop) {
        return Row(children: List.generate(4, (i) => Expanded(child: Padding(padding: EdgeInsets.only(left: i == 0 ? 0 : 16), child: card))));
      } else if (isTablet) {
        return Column(children: [Row(children: [Expanded(child: card), const SizedBox(width: 16), Expanded(child: card)]), const SizedBox(height: 16), Row(children: [Expanded(child: card), const SizedBox(width: 16), Expanded(child: card)])]);
      } else {
        return Column(children: List.generate(4, (i) => Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 12), child: card)));
      }
    });
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        gradientBorder: AppColors.dangerGradient,
        padding: const EdgeInsets.all(24),
        animate: false,
        child: Row(children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.cloud_off_rounded, color: AppColors.danger, size: 24)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Something went wrong', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(error, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSecondary : AppColors.lightSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 16),
          SizedBox(
            height: 36,
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
        ]),
      ),
    );
  }
}
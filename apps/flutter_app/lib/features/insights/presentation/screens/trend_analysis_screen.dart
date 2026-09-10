import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/config/app_colors.dart';
import '../../../../core/widgets/premium_widgets.dart';

// ═══════════════════════════════════════════════════════════
// 📈 TREND ANALYSIS SCREEN
// Displays price trends, charts, and AI-generated trend insights.
// ═══════════════════════════════════════════════════════════
class TrendAnalysisScreen extends ConsumerStatefulWidget {
  final String? competitorId;
  final String? competitorName;

  const TrendAnalysisScreen({
    super.key,
    this.competitorId,
    this.competitorName,
  });

  @override
  ConsumerState<TrendAnalysisScreen> createState() =>
      _TrendAnalysisScreenState();
}

class _TrendAnalysisScreenState extends ConsumerState<TrendAnalysisScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  String? _error;
  
  int _trendingUp = 0;
  int _trendingDown = 0;
  int _stable = 0;
  
  List<Map<String, dynamic>> _trendInsights = [];

  @override
  void initState() {
    super.initState();
    _fetchTrendData();
  }

  Future<void> _fetchTrendData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // ✅ FIX: Apply all filters (.eq) BEFORE ordering (.order)
      PostgrestFilterBuilder query = _supabase
          .from('ai_insights')
          .select()
          .eq('type', 'trend');

      if (widget.competitorId != null) {
        query = query.eq('competitor_id', widget.competitorId!);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(20);

      if (mounted) {
        setState(() {
          _trendInsights = List<Map<String, dynamic>>.from(response ?? []);
          
          // Calculate summary based on insights titles/summaries
          _trendingUp = _trendInsights.where((i) => 
            (i['title']?.toString().toLowerCase().contains('increasing') ?? false) || 
            (i['title']?.toString().toLowerCase().contains('up') ?? false)
          ).length;
          
          _trendingDown = _trendInsights.where((i) => 
            (i['title']?.toString().toLowerCase().contains('decreasing') ?? false) || 
            (i['title']?.toString().toLowerCase().contains('down') ?? false)
          ).length;
          
          _stable = _trendInsights.where((i) => 
            (i['title']?.toString().toLowerCase().contains('stable') ?? false)
          ).length;
          
          if (_trendingUp == 0 && _trendingDown == 0 && _stable == 0 && _trendInsights.isNotEmpty) {
            _stable = _trendInsights.length; 
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedGradientBackground(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 70, bottom: 16),
                title: Text(
                  widget.competitorName ?? 'Trend Analysis',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    letterSpacing: -0.5,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.info.withOpacity(0.2),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _isLoading ? null : _fetchTrendData,
                  tooltip: 'Refresh Trends',
                ),
              ],
            ),

            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: _ErrorState(error: _error!, onRetry: _fetchTrendData),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _TrendSummaryCards(
                      up: _trendingUp,
                      down: _trendingDown,
                      stable: _stable,
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
                    
                    const SizedBox(height: 24),

                    _TrendChartWidget(
                      up: _trendingUp,
                      down: _trendingDown,
                      stable: _stable,
                    ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1, end: 0),
                    
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'AI Trend Insights',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_trendInsights.isEmpty)
                      _EmptyTrendState().animate().fadeIn(duration: 400.ms, delay: 200.ms)
                    else
                      ..._trendInsights.map((insight) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _TrendInsightCard(insight: insight)
                                .animate()
                                .fadeIn(duration: 400.ms)
                                .slideY(begin: 0.1, end: 0),
                          )),
                    
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 📊 TREND SUMMARY CARDS
// ═══════════════════════════════════════════════════════════
class _TrendSummaryCards extends StatelessWidget {
  final int up;
  final int down;
  final int stable;

  const _TrendSummaryCards({required this.up, required this.down, required this.stable});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(
            label: 'Price Up',
            value: up,
            color: AppColors.danger,
            icon: Icons.trending_up_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniStatCard(
            label: 'Price Down',
            value: down,
            color: AppColors.success,
            icon: Icons.trending_down_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniStatCard(
            label: 'Stable',
            value: stable,
            color: AppColors.info,
            icon: Icons.remove_rounded,
          ),
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      animate: false,
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 📈 TREND CHART WIDGET
// ═══════════════════════════════════════════════════════════
class _TrendChartWidget extends StatelessWidget {
  final int up;
  final int down;
  final int stable;

  const _TrendChartWidget({required this.up, required this.down, required this.stable});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = up + down + stable;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart_rounded, color: AppColors.info, size: 20),
              const SizedBox(width: 8),
              Text(
                'Price Stability Distribution',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: total == 0
                ? Center(
                    child: Text(
                      'Run a scan to generate trend data',
                      style: TextStyle(color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary),
                    ),
                  )
                : PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(
                          value: up.toDouble(),
                          title: '$up',
                          color: AppColors.danger,
                          radius: 50,
                          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        PieChartSectionData(
                          value: down.toDouble(),
                          title: '$down',
                          color: AppColors.success,
                          radius: 50,
                          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        PieChartSectionData(
                          value: stable.toDouble(),
                          title: '$stable',
                          color: AppColors.info,
                          radius: 50,
                          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ChartLegend(color: AppColors.danger, label: 'Increasing'),
              const SizedBox(width: 16),
              _ChartLegend(color: AppColors.success, label: 'Decreasing'),
              const SizedBox(width: 16),
              _ChartLegend(color: AppColors.info, label: 'Stable'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 💎 TREND INSIGHT CARD
// ═══════════════════════════════════════════════════════════
class _TrendInsightCard extends StatelessWidget {
  final Map<String, dynamic> insight;
  const _TrendInsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final severity = (insight['severity'] ?? 'medium').toString().toLowerCase();
    
    Color severityColor;
    switch (severity) {
      case 'critical': severityColor = AppColors.danger; break;
      case 'high': severityColor = AppColors.warning; break;
      case 'low': severityColor = AppColors.success; break;
      default: severityColor = AppColors.info;
    }

    return GlassCard(
      padding: const EdgeInsets.all(16),
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.trending_up_rounded, color: severityColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insight['title'] ?? 'Trend Insight',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: severityColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        severity.toUpperCase(),
                        style: TextStyle(
                          color: severityColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insight['summary'] ?? '',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
            ),
          ),
          if (insight['ai_recommendation'] != null && (insight['ai_recommendation'] as String).isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.info.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, color: AppColors.info, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insight['ai_recommendation'],
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                insight['created_at'] != null 
                    ? timeago.format(DateTime.parse(insight['created_at'])) 
                    : 'Recently',
                style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🕳️ EMPTY STATE
// ═══════════════════════════════════════════════════════════
class _EmptyTrendState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      animate: false,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.show_chart_rounded, color: AppColors.info, size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            'Building Trend History...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Trend analysis requires at least 2 scans of the same competitor to detect price changes. Run another scan to start seeing trends!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ⚠️ ERROR STATE
// ═══════════════════════════════════════════════════════════
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.danger, size: 48),
            const SizedBox(height: 16),
            Text(
              'Failed to load trend data',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            GradientButton(
              text: 'Try Again',
              icon: Icons.refresh_rounded,
              gradient: AppColors.dangerGradient,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
import 'dart:async';
import 'dart:math' as math;  
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_colors.dart';
import '../../../../core/widgets/premium_widgets.dart';
import '../../../../core/extensions/widget_extensions.dart';
import '../providers/insights_providers.dart';
import '../../data/insights_repository.dart''';
                },
              ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              sliver: SliverToBoxAdapter(
                child: statsAsync.when(
                  data: (stats) => _PremiumStatsGrid(stats: stats),
                  loading: () => const _StatsGridLoading(),
                  error: (error, _) => _ErrorState(
                    error: error.toString(),
                    onRetry: () => ref.invalidate(insightsStatsProvider),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
                child: _SeverityFilterBar(currentFilter: currentFilter, ref: ref),
              ).animate(delay: 150.ms).fadeIn(),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 16, 32, 12),
                child: _ListHeader(
                  filteredCount: filteredInsights.length,
                  totalCount: allInsightsAsync.valueOrNull?.length ?? 0,
                  currentFilter: currentFilter,
                ),
              ).animate(delay: 200.ms).fadeIn(),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 80),
              sliver: SliverToBoxAdapter(
                child: allInsightsAsync.when(
                  data: (_) {
                    if (filteredInsights.isEmpty) {
                      return _EmptyInsightsState(
                        hasFilter: currentFilter != null ||
                            _searchController.text.isNotEmpty,
                        searchQuery: _searchController.text,
                        onClear: () {
                          _searchController.clear();
                          ref.read(insightsSearchQueryProvider.notifier).state = '';
                          ref.read(severityFilterProvider.notifier).state = null;
                        },
                      );
                    }
                    return _InsightsList(insights: filteredInsights);
                  },
                  loading: () => const _InsightsListLoading(),
                  error: (error, _) => _ErrorState(
                    error: error.toString(),
                    onRetry: () => ref.invalidate(insightsListProvider),
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
  final AsyncValue<Map<String, int>> statsAsync;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClear;

  const _HeroHeader({
    required this.statsAsync,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchChanged,
    required this.onClear,
  });

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
              ? [
                  AppColors.purple.withOpacity(0.15),
                  AppColors.darkAccent.withOpacity(0.08),
                  Colors.transparent,
                ]
              : [
                  AppColors.purple.withOpacity(0.12),
                  AppColors.lightAccent.withOpacity(0.06),
                  Colors.transparent,
                ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: AppColors.pinkGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.purple.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'insights.title'.tr(),
                    style: GoogleFonts.sora(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                      color: isDark
                          ? AppColors.darkPrimary
                          : AppColors.lightPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'insights.subtitle'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.darkSecondary
                          : AppColors.lightSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.purple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.purple.withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.purple,
                    shape: BoxShape.circle,
                  ),
                ).animate(onPlay: (c) => c.repeat(period: 1500.ms))
                 .fadeIn().fadeOut(delay: 750.ms),
                const SizedBox(width: 6),
                const Text('AI POWERED',
                    style: TextStyle(
                      color: Color(0xFF8B5CF6),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    )),
              ]),
            ),
          ]),
          const SizedBox(height: 28),
          _PremiumSearchBar(
            controller: searchController,
            focusNode: searchFocusNode,
            onChanged: onSearchChanged,
            onClear: onClear,
            totalCount: statsAsync.valueOrNull?['total''Search insights, trends, competitors...''${widget.totalCount}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
              ),
              GestureDetector(
                onTap: widget.onClear,
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                    size: 18,
                  ),
                ),
              ),
            ] else
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 14,
                      color: Color(0xFF8E8E93),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '⌘ F',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 📊 PREMIUM STATS GRID
// ═══════════════════════════════════════════════════════════
class _PremiumStatsGrid extends StatelessWidget {
  final Map<String, int> stats;
  const _PremiumStatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth > 900;
      final isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 900;

      final cards = [
        _StatCardData(
          icon: Icons.auto_awesome_rounded,
          label: 'insights.total'.tr(),
          value: stats['total'] ?? 0,
          color: AppColors.purple,
          gradient: AppColors.pinkGradient,
          sparkline: const [1, 2, 2, 3, 3, 4, 4, 5, 6, 7],
        ),
        _StatCardData(
          icon: Icons.priority_high_rounded,
          label: 'insights.critical'.tr(),
          value: stats['critical'] ?? 0,
          color: AppColors.danger,
          gradient: AppColors.dangerGradient,
          sparkline: const [3, 2, 2, 2, 1, 2, 1, 1, 0, 1],
        ),
        _StatCardData(
          icon: Icons.trending_up_rounded,
          label: 'insights.high'.tr(),
          value: stats['high'] ?? 0,
          color: AppColors.warning,
          gradient: AppColors.warningGradient,
          sparkline: const [2, 3, 3, 4, 3, 4, 5, 4, 5, 6],
        ),
        _StatCardData(
          icon: Icons.event_available_rounded,
          label: 'insights.this_week'.tr(),
          value: stats['thisWeek'] ?? 0,
          color: AppColors.success,
          gradient: AppColors.successGradient,
          sparkline: const [0, 1, 1, 2, 2, 3, 2, 3, 4, 5],
        ),
      ];

      if (isDesktop) {
        return Row(
          children: cards.asMap().entries.map((e) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: e.key == 0 ? 0 : 16),
                child: _AnimatedStatCard(data: e.value).stagger(e.key),
              ),
            );
          }).toList(),
        );
      } else if (isTablet) {
        return Column(children: [
          Row(children: [
            Expanded(child: _AnimatedStatCard(data: cards[0]).stagger(0)),
            const SizedBox(width: 16),
            Expanded(child: _AnimatedStatCard(data: cards[1]).stagger(1)),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _AnimatedStatCard(data: cards[2]).stagger(2)),
            const SizedBox(width: 16),
            Expanded(child: _AnimatedStatCard(data: cards[3]).stagger(3)),
          ]),
        ]);
      } else {
        return Column(
          children: cards.asMap().entries.map((e) {
            return Padding(
              padding: EdgeInsets.only(top: e.key == 0 ? 0 : 12),
              child: _AnimatedStatCard(data: e.value).stagger(e.key),
            );
          }).toList(),
        );
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

  const _StatCardData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.gradient,
    required this.sparkline,
  });
}

class _AnimatedStatCard extends StatelessWidget {
  final _StatCardData data;
  const _AnimatedStatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Semantics(
        label: '${data.label}: ${data.value}',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: data.gradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: data.color.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(data.icon, color: Colors.white, size: 22),
            ),
            _Sparkline(data: data.sparkline, color: data.color),
          ]),
          const SizedBox(height: 16),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: data.value),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text(
              v.toString(),
              style: GoogleFonts.sora(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                letterSpacing: -1,
                height: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
              letterSpacing: 0.2,
            ),
          ),
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
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(60, 28),
      painter: _SparklinePainter(data: data, color: color),
    );
  }
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

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.25), color.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    final lastX = (data.length - 1) * stepX;
    final lastY = size.height -
        (((data.last - minVal) / range) * size.height * 0.8) -
        (size.height * 0.1);
    canvas.drawCircle(Offset(lastX, lastY), 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.data != data || old.color != color;
}

// ═══════════════════════════════════════════════════════════
// 🏷️ SEVERITY FILTER BAR
// ═══════════════════════════════════════════════════════════
class _SeverityFilterBar extends StatelessWidget {
  final String? currentFilter;
  final WidgetRef ref;

  const _SeverityFilterBar({required this.currentFilter, required this.ref});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _FilterChip(
          label: 'insights.filter_all'.tr(),
          isSelected: currentFilter == null,
          color: AppColors.darkSecondary,
          count: ref.watch(insightsListProvider).valueOrNull?.length ?? 0,
          onTap: () => ref.read(severityFilterProvider.notifier).state = null,
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'insights.filter_critical'.tr(),
          isSelected: currentFilter == 'critical',
          color: AppColors.danger,
          count: _countBySeverity(ref, 'critical'),
          onTap: () =>
              ref.read(severityFilterProvider.notifier).state = 'critical',
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'insights.filter_high'.tr(),
          isSelected: currentFilter == 'high',
          color: AppColors.warning,
          count: _countBySeverity(ref, 'high'),
          onTap: () => ref.read(severityFilterProvider.notifier).state = 'high',
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'insights.filter_medium'.tr(),
          isSelected: currentFilter == 'medium',
          color: AppColors.info,
          count: _countBySeverity(ref, 'medium'),
          onTap: () =>
              ref.read(severityFilterProvider.notifier).state = 'medium',
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'insights.filter_low'.tr(),
          isSelected: currentFilter == 'low',
          color: AppColors.success,
          count: _countBySeverity(ref, 'low'),
          onTap: () => ref.read(severityFilterProvider.notifier).state = 'low',
        ),
      ]),
    );
  }

  int _countBySeverity(WidgetRef ref, String severity) {
    final insights = ref.watch(insightsListProvider).valueOrNull ?? [];
    return insights.where((i) => i.severity.toLowerCase() == severity).length;
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final int count;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.15)
                : (isDark
                    ? AppColors.darkSurfaceVariant
                    : AppColors.lightSurfaceVariant),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color.withOpacity(0.5) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ).animate(onPlay: (c) => c.repeat(period: 1500.ms))
             .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2),
                    duration: 750.ms)
             .then()
             .scale(begin: const Offset(1.2, 1.2), end: const Offset(0.8, 0.8),
                    duration: 750.ms),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? color
                    : (isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
                letterSpacing: 0.2,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withOpacity(0.2)
                      : (isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? color
                        : (isDark
                            ? AppColors.darkSecondary
                            : AppColors.lightSecondary),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 📋 LIST HEADER
// ═══════════════════════════════════════════════════════════
class _ListHeader extends StatelessWidget {
  final int filteredCount;
  final int totalCount;
  final String? currentFilter;

  const _ListHeader({
    required this.filteredCount,
    required this.totalCount,
    required this.currentFilter,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFiltered = filteredCount < totalCount || currentFilter != null;

    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppColors.darkAccent.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.lightbulb_rounded, color: Colors.white, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'insights.all_insights'.tr(),
            style: (Theme.of(context).textTheme.titleLarge ?? const TextStyle()).copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            isFiltered
                ? '$filteredCount of $totalCount insights match your filters'
                : '$totalCount strategic insights available',
            style: (Theme.of(context).textTheme.bodySmall ?? const TextStyle()).copyWith(
                  color: isDark
                      ? AppColors.darkSecondary
                      : AppColors.lightSecondary,
                ),
          ),
        ]),
      ),
      if (isFiltered)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.purple.withOpacity(0.3)),
          ),
          child: Text(
            '$filteredCount / $totalCount',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8B5CF6),
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════
// 📝 INSIGHTS LIST
// ═══════════════════════════════════════════════════════════
class _InsightsList extends StatelessWidget {
  final List<AIInsight> insights;
  const _InsightsList({required this.insights});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: insights.asMap().entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _PremiumInsightCard(insight: entry.value)
              .animate()
              .fadeIn(
                duration: 500.ms,
                delay: Duration(milliseconds: 80 * entry.key),
              )
              .slideX(
                begin: -0.05,
                end: 0,
                duration: 600.ms,
                delay: Duration(milliseconds: 80 * entry.key),
              ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 💎 PREMIUM INSIGHT CARD — AI Enhanced & Expandable
// ═══════════════════════════════════════════════════════════
class _PremiumInsightCard extends StatefulWidget {
  final AIInsight insight;
  const _PremiumInsightCard({required this.insight});

  @override
  State<_PremiumInsightCard> createState() => _PremiumInsightCardState();
}

class _PremiumInsightCardState extends State<_PremiumInsightCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final severityColor = _getSeverityColor(widget.insight.severity);
    
    final typeIcon = _getTypeIcon(widget.insight.severity);
    final aiRec = (widget.insight as dynamic).aiRecommendation as String? ?? '';

    return GlassCard(
      padding: EdgeInsets.zero,
      animate: false,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 4,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [severityColor, severityColor.withOpacity(0.3)],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),
            Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(typeIcon, color: severityColor, size: 22),
                ),
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withOpacity(0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _SeverityBadge(
                    severity: widget.insight.severity,
                    color: severityColor,
                  ),
                  if (widget.insight.competitorName != null) ...[
                    const SizedBox(width: 8),
                    _CompetitorChip(name: widget.insight.competitorName!),
                  ],
                  const Spacer(),
                  Text(
                    widget.insight.timeAgoFormatted,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkSecondary
                          : AppColors.lightSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Text(
                  widget.insight.title,
                  style: (Theme.of(context).textTheme.titleMedium ?? const TextStyle()).copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: isDark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary,
                      ),
                  maxLines: _expanded ? null : 2,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                _FormattedText(
                  text: widget.insight.summary,
                  style: (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
                        color: isDark
                            ? AppColors.darkSecondary
                            : AppColors.lightSecondary,
                        height: 1.5,
                      ),
                  maxLines: _expanded ? null : 2,
                ),
                if (!_expanded) ...[
                  const SizedBox(height: 12),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 12,
                            color: Color(0xFF8B5CF6),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'AI Analysis',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8B5CF6),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Tap to expand',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8B5CF6),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 12, color: Color(0xFF8B5CF6)),
                  ]),
                ],
              ]),
            ),
            const SizedBox(width: 12),
            AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 300),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                size: 22,
              ),
            ),
          ]),
        ),

        if (_expanded)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Divider(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              const SizedBox(height: 16),

              if (aiRec.isNotEmpty) ...[
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.psychology_rounded,
                      color: Color(0xFF8B5CF6),
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Strategic Recommendation',
                    style: (Theme.of(context).textTheme.labelMedium ?? const TextStyle()).copyWith(
                          color: const Color(0xFF8B5CF6),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'AI GENERATED',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8B5CF6),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.lightSurfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: _FormattedText(
                    text: aiRec,
                    style: (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
                          height: 1.7,
                          color: isDark
                              ? AppColors.darkPrimary
                              : AppColors.lightPrimary,
                        ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Row(children: [
                _InsightAction(
                  icon: Icons.bookmark_outline_rounded,
                  label: 'Save',
                  color: AppColors.purple,
                  onTap: () {},
                ),
                const SizedBox(width: 12),
                _InsightAction(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  color: AppColors.info,
                  onTap: () {},
                ),
                const Spacer(),
                Text(
                  widget.insight.timeAgoFormatted,
                  style: (Theme.of(context).textTheme.bodySmall ?? const TextStyle()).copyWith(
                        color: isDark
                            ? AppColors.darkSecondary
                            : AppColors.lightSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ]),
            ]),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0),
      ]),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return AppColors.danger;
      case 'high':
        return AppColors.warning;
      case 'medium':
        return AppColors.info;
      default:
        return AppColors.success;
    }
  }

  IconData _getTypeIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Icons.priority_high_rounded;
      case 'high':
        return Icons.trending_up_rounded;
      case 'medium':
        return Icons.insights_rounded;
      case 'low':
        return Icons.lightbulb_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }
}

// ═══════════════════════════════════════════════════════════
// 📝 FORMATTED TEXT WIDGET (Handles bullet points) - FIXED
// ═══════════════════════════════════════════════════════════
class _FormattedText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final int? maxLines;

  const _FormattedText({
    required this.text,
    required this.style,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    
    if (lines.length == 1) {
      return Text(text, style: style, maxLines: maxLines);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.asMap().entries.map((entry) {
        final index = entry.key;
        
        if (maxLines != null && index >= maxLines!) {
          return const SizedBox.shrink();
        }
        
        final line = entry.value.trim();
        final int? safeMaxLines = maxLines != null ? maxLines! - index : null;

        if (line.startsWith('-') || line.startsWith('•')) {
          final content = line.substring(1).trim();
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Color(0xFF8B5CF6),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    content,
                    style: style,
                    maxLines: safeMaxLines,
                  ),
                ),
              ],
            ),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              line,
              style: style,
              maxLines: safeMaxLines,
            ),
          );
        }
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🔧 SMALL COMPONENTS
// ═══════════════════════════════════════════════════════════
class _SeverityBadge extends StatelessWidget {
  final String severity;
  final Color color;
  const _SeverityBadge({required this.severity, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ).animate(onPlay: (c) => c.repeat(period: 1500.ms)).fadeIn().fadeOut(delay: 750.ms),
        const SizedBox(width: 6),
        Text(
          severity.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ]),
    );
  }
}

class _CompetitorChip extends StatelessWidget {
  final String name;
  const _CompetitorChip({required this.name});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.storefront_rounded, size: 12, color: Color(0xFF8E8E93)),
        const SizedBox(width: 4),
        Text(
          name,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
          ),
        ),
      ]),
    );
  }
}

class _InsightAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _InsightAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                )),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🕳️ EMPTY STATE
// ═══════════════════════════════════════════════════════════
class _EmptyInsightsState extends StatelessWidget {
  final bool hasFilter;
  final String searchQuery;
  final VoidCallback onClear;

  const _EmptyInsightsState({
    required this.hasFilter,
    required this.searchQuery,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      animate: false,
      child: Column(children: [
        Stack(alignment: Alignment.center, children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.purple.withOpacity(0.15),
                AppColors.darkAccent.withOpacity(0.1),
              ]),
              shape: BoxShape.circle,
            ),
          ).animate(onPlay: (c) => c.repeat(period: 3.seconds))
           .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05),
                  duration: 1500.ms).then()
           .scale(begin: const Offset(1.05, 1.05), end: const Offset(0.95, 0.95),
                  duration: 1500.ms),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: hasFilter
                  ? const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)])
                  : AppColors.pinkGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.purple.withOpacity(0.4),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Icon(
              hasFilter ? Icons.filter_alt_off_rounded : Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ]),
        const SizedBox(height: 32),
        Text(
          hasFilter
              ? 'insights.no_results'.tr()
              : 'insights.empty_title'.tr(),
          style: (Theme.of(context).textTheme.headlineMedium ?? const TextStyle()).copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Text(
            hasFilter
                ? (searchQuery.isNotEmpty
                    ? 'No insights match "$searchQuery". Try a different search or filter.'
                    : 'insights.try_different_filter'.tr())
                : 'insights.empty_subtitle'.tr(),
            textAlign: TextAlign.center,
            style: (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
                  color: isDark
                      ? AppColors.darkSecondary
                      : AppColors.lightSecondary,
                  height: 1.6,
                ),
          ),
        ),
        if (hasFilter) ...[
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear_rounded, size: 18),
            label: const Text('Clear all filters'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ⏳ LOADING STATES
// ═══════════════════════════════════════════════════════════
class _StatsGridLoading extends StatelessWidget {
  const _StatsGridLoading();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth > 900;
      final isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 900;

      final card = SizedBox(
        height: 140,
        child: ShimmerLoading(
          width: double.infinity,
          height: double.infinity,
          borderRadius: 20,
        ),
      );

      if (isDesktop) {
        return Row(
          children: List.generate(
            4,
            (i) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 16),
                child: card,
              ),
            ),
          ),
        );
      } else if (isTablet) {
        return Column(children: [
          Row(children: [Expanded(child: card), const SizedBox(width: 16), Expanded(child: card)]),
          const SizedBox(height: 16),
          Row(children: [Expanded(child: card), const SizedBox(width: 16), Expanded(child: card)]),
        ]);
      } else {
        return Column(
          children: List.generate(
            4,
            (i) => Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 12), child: card),
          ),
        );
      }
    });
  }
}

class _InsightsListLoading extends StatelessWidget {
  const _InsightsListLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (i) => Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: ShimmerLoading(
            width: double.infinity,
            height: 120,
            borderRadius: 20,
          ).animate(delay: Duration(milliseconds: 100 * i)).fadeIn(),
        ),
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
    return Padding(
      padding: const EdgeInsets.all(32),
      child: GlassCard(
        gradientBorder: AppColors.dangerGradient,
        padding: const EdgeInsets.all(32),
        animate: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  color: AppColors.danger, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              'Failed to load insights',
              style: (Theme.of(context).textTheme.titleLarge ?? const TextStyle()).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkSecondary
                        : AppColors.lightSecondary,
                  ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            GradientButton(
              text: 'Retry',
              icon: Icons.refresh_rounded,
              gradient: AppColors.dangerGradient,
              onPressed: onRetry,
            ),
          ]),
        ),
      ),
    );
  }
}
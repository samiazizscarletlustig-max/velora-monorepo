import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../shared/widgets/velora_card.dart';
import '../providers/insights_providers.dart';
import '../../data/insights_repository.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statsAsync = ref.watch(insightsStatsProvider);
    final filteredInsights = ref.watch(filteredInsightsProvider);
    final allInsightsAsync = ref.watch(insightsListProvider);
    final currentFilter = ref.watch(severityFilterProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ═══ Header ═══
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'insights.title'.tr(),
                  style: theme.textTheme.displayLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'insights.subtitle'.tr(),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
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

            // ═══ Search Bar ═══
            VeloraCard(
              padding: EdgeInsets.zero,
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  ref.read(insightsSearchQueryProvider.notifier).state = value;
                },
                decoration: InputDecoration(
                  hintText: 'insights.search_hint'.tr(),
                  prefixIcon: Icon(
                    Icons.search,
                    color: theme.colorScheme.secondary,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(insightsSearchQueryProvider.notifier).state = '';
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ═══ Severity Filter Pills ═══
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterPill(
                    label: 'insights.filter_all'.tr(),
                    isSelected: currentFilter == null,
                    onTap: () => ref.read(severityFilterProvider.notifier).state = null,
                    color: const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 8),
                  _FilterPill(
                    label: 'insights.filter_critical'.tr(),
                    isSelected: currentFilter == 'critical',
                    onTap: () => ref.read(severityFilterProvider.notifier).state = 'critical',
                    color: const Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 8),
                  _FilterPill(
                    label: 'insights.filter_high'.tr(),
                    isSelected: currentFilter == 'high',
                    onTap: () => ref.read(severityFilterProvider.notifier).state = 'high',
                    color: const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 8),
                  _FilterPill(
                    label: 'insights.filter_medium'.tr(),
                    isSelected: currentFilter == 'medium',
                    onTap: () => ref.read(severityFilterProvider.notifier).state = 'medium',
                    color: const Color(0xFF3B82F6),
                  ),
                  const SizedBox(width: 8),
                  _FilterPill(
                    label: 'insights.filter_low'.tr(),
                    isSelected: currentFilter == 'low',
                    onTap: () => ref.read(severityFilterProvider.notifier).state = 'low',
                    color: const Color(0xFF10B981),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ═══ Insights List Header ═══
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'insights.all_insights'.tr(),
                  style: theme.textTheme.titleLarge,
                ),
                allInsightsAsync.whenOrNull(
                      data: (data) => Text(
                        '${filteredInsights.length} / ${data.length}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ) ??
                    const SizedBox.shrink(),
              ],
            ),
            const SizedBox(height: 16),

            // ═══ Insights List ═══
            allInsightsAsync.when(
              data: (_) {
                if (filteredInsights.isEmpty) {
                  return _EmptyState(
                    hasFilter: currentFilter != null || _searchController.text.isNotEmpty,
                  );
                }
                return Column(
                  children: filteredInsights
                      .map<Widget>(
                        (insight) => _InsightCard(
                          insight: insight,
                          onTap: () => _showInsightDetails(context, insight),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const _InsightsListLoading(),
              error: (error, _) => _ErrorCard(error: error.toString()),
            ),
          ],
        ),
      ),
    );
  }

  void _showInsightDetails(BuildContext context, AIInsight insight) {
    final theme = Theme.of(context);
    final severityColor = _getSeverityColor(insight.severity);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Severity badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    insight.severity.toUpperCase(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: severityColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  insight.title,
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 12),

                // Meta info
                Row(
                  children: [
                    if (insight.competitorName != null) ...[
                      Icon(
                        Icons.storefront_outlined,
                        size: 14,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        insight.competitorName!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      insight.timeAgoFormatted,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Summary section
                Text(
                  'insights.summary'.tr(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  insight.summary,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),

                // Detailed analysis section
                if (insight.detailedAnalysis.isNotEmpty) ...[
                  Text(
                    'insights.detailed_analysis'.tr(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  VeloraCard(
                    child: Text(
                      insight.detailedAnalysis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.7,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return const Color(0xFFEF4444);
      case 'high':
        return const Color(0xFFF59E0B);
      case 'medium':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF10B981);
    }
  }
}

// ═══════════════════════════════════════════
// Filter Pill Widget
// ═══════════════════════════════════════════

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _FilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : theme.colorScheme.secondary.withOpacity(0.3),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isSelected ? color : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Insight Card Widget
// ═══════════════════════════════════════════

class _InsightCard extends StatelessWidget {
  final AIInsight insight;
  final VoidCallback onTap;

  const _InsightCard({
    required this.insight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final severityColor = _getSeverityColor(insight.severity);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: VeloraCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Severity indicator (vertical bar)
              Container(
                width: 4,
                height: 70,
                decoration: BoxDecoration(
                  color: severityColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: severity badge + competitor + time
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: severityColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            insight.severity.toUpperCase(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: severityColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (insight.competitorName != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.storefront_outlined,
                            size: 12,
                            color: theme.colorScheme.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            insight.competitorName!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          insight.timeAgoFormatted,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Title
                    Text(
                      insight.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Summary
                    Text(
                      insight.summary,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Read more hint
                    Row(
                      children: [
                        Text(
                          'insights.tap_to_read'.tr(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF4F46E5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward,
                          size: 12,
                          color: Color(0xFF4F46E5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return const Color(0xFFEF4444);
      case 'high':
        return const Color(0xFFF59E0B);
      case 'medium':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF10B981);
    }
  }
}

// ═══════════════════════════════════════════
// Stats Grid Widget
// ═══════════════════════════════════════════

class _StatsGrid extends StatelessWidget {
  final Map<String, int> stats;
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
              icon: Icons.lightbulb_outline,
              title: 'insights.total'.tr(),
              value: stats['total'].toString(),
              color: const Color(0xFF4F46E5),
            ),
            _StatCard(
              icon: Icons.warning_amber_outlined,
              title: 'insights.critical'.tr(),
              value: stats['critical'].toString(),
              color: const Color(0xFFEF4444),
            ),
            _StatCard(
              icon: Icons.trending_up,
              title: 'insights.high'.tr(),
              value: stats['high'].toString(),
              color: const Color(0xFFF59E0B),
            ),
            _StatCard(
              icon: Icons.calendar_today_outlined,
              title: 'insights.this_week'.tr(),
              value: stats['thisWeek'].toString(),
              color: const Color(0xFF10B981),
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
// Empty State Widget
// ═══════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final bool hasFilter;

  const _EmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return VeloraCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: Column(
            children: [
              Icon(
                hasFilter ? Icons.filter_alt_off : Icons.lightbulb_outline,
                size: 64,
                color: theme.colorScheme.secondary.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                hasFilter
                    ? 'insights.no_results'.tr()
                    : 'insights.empty_title'.tr(),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                hasFilter
                    ? 'insights.try_different_filter'.tr()
                    : 'insights.empty_subtitle'.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Loading & Error States
// ═══════════════════════════════════════════

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

class _InsightsListLoading extends StatelessWidget {
  const _InsightsListLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: VeloraCard(
            child: SizedBox(
              height: 120,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
      ),
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
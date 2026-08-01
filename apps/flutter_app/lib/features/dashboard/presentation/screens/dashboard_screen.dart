import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/velora_card.dart';
import '../providers/dashboard_providers.dart';
import '../../data/dashboard_repository.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final insightsAsync = ref.watch(recentInsightsProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ═══ Header ═══
            Text(
              'dashboard.welcome'.tr(),
              style: theme.textTheme.displayLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'dashboard.subtitle'.tr(),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 32),

            // ═══ Stats Grid ═══
            statsAsync.when(
              data: (stats) => _StatsGrid(stats: stats),
              loading: () => const _StatsGridLoading(),
              error: (error, _) => _ErrorCard(error: error.toString()),
            ),
            const SizedBox(height: 32),

            // ═══ Recent Insights Section ═══
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'dashboard.recent_insights'.tr(),
                  style: theme.textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: () => context.go('/insights'),
                  child: Text('dashboard.view_all'.tr()),
                ),
              ],
            ),
            const SizedBox(height: 16),

            insightsAsync.when(
              data: (insights) => _InsightsList(insights: insights),
              loading: () => const _InsightsListLoading(),
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
  final DashboardStats stats;
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
          // ✅ نسبة محسّنة للتناسب مع التصميم الجديد
          childAspectRatio: isDesktop ? 2.2 : 1.6,
          children: [
            _StatCard(
              icon: Icons.storefront_outlined,
              title: 'dashboard.competitors'.tr(),
              value: stats.totalCompetitors.toString(),
              color: const Color(0xFF4F46E5),
            ),
            _StatCard(
              icon: Icons.shopping_bag_outlined,
              title: 'dashboard.products'.tr(),
              value: stats.totalProducts.toString(),
              color: const Color(0xFF10B981),
            ),
            _StatCard(
              icon: Icons.lightbulb_outline,
              title: 'dashboard.insights'.tr(),
              value: stats.totalInsights.toString(),
              color: const Color(0xFFF59E0B),
            ),
            _StatCard(
              icon: Icons.warning_amber_outlined,
              title: 'dashboard.critical'.tr(),
              value: stats.criticalInsights.toString(),
              color: const Color(0xFFEF4444),
            ),
          ],
        );
      },
    );
  }
}

// ✅ تصميم جديد بالكامل: أفقي وأكثر كفاءة
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
      padding: const EdgeInsets.all(16), // ✅ padding أصغر
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, // ✅ يمنع التمدد غير الضروري
        children: [
          // ═══ الصف الأول: الأيقونة + القيمة ═══
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
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ═══ الصف الثاني: العنوان ═══
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
// Insights List Widget
// ═══════════════════════════════════════════

class _InsightsList extends StatelessWidget {
  final List<InsightPreview> insights;
  const _InsightsList({required this.insights});

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return VeloraCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'dashboard.no_insights'.tr(),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: insights
          .map<Widget>((insight) => _InsightCard(insight: insight))
          .toList(),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final InsightPreview insight;
  const _InsightCard({required this.insight});

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final severityColor = _getSeverityColor(insight.severity);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: VeloraCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Severity indicator
            Container(
              width: 4,
              height: 60,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          insight.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 16,
                          ),
                        ),
                      ),
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
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    insight.summary,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(insight.createdAt),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontSize: 12,
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}

// ═══════════════════════════════════════════
// Loading States
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
    return VeloraCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: CircularProgressIndicator(strokeWidth: 2),
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
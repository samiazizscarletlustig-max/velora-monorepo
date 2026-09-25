import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart''competitor_analysis_screen.dart';
import '../../../insights/presentation/screens/trend_analysis_screen.dart''../../../billing/data/tier_repository.dart';
import '../../../billing/widgets/upgrade_dialog.dart';

import '../../../../core/config/app_colors.dart';
import '../../../../core/widgets/premium_widgets.dart';
import '../../data/competitors_repository.dart';
import '../providers/competitors_providers.dart''ve reached the $max-competitor limit on your ${tier.toUpperCase()} plan. Upgrade to track more competitors with faster scan intervals.",
        targetTier: tier == 'free' ? 'pro' : 'pro_plus',
      );
      return;
    }

    _showPremiumAddDialog(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final competitorsAsync = ref.watch(competitorsListProvider);
    final statsAsync = ref.watch(competitorsStatsProvider);

    debugPrint('🏗️ [CompetitorsScreen] Building... Loading: ${competitorsAsync.isLoading}, Error: ${competitorsAsync.hasError}''❌ [CompetitorsScreen] Error caught: $e');
                return _ErrorState(
                  error: e.toString(),
                  onRetry: () => ref.invalidate(competitorsListProvider),
                );
              },
              data: (competitors) {
                debugPrint('✅ [CompetitorsScreen] Data loaded. Count: ${competitors.length}''').toLowerCase().contains(query) ||
            (c.domain ?? '').toLowerCase().contains(query);
      }).toList();
    }

    switch (_sortMode) {
      case CompetitorSortMode.nameAsc:
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case CompetitorSortMode.nameDesc:
        filtered.sort((a, b) => b.name.compareTo(a.name));
        break;
      case CompetitorSortMode.productsDesc:
        filtered.sort((a, b) => b.productsCount.compareTo(a.productsCount));
        break;
      case CompetitorSortMode.recentlyScanned:
        filtered.sort((a, b) {
          final aDate = a.lastScanAt ?? DateTime(2000);
          final bDate = b.lastScanAt ?? DateTime(2000);
          return bDate.compareTo(aDate);
        });
        break;
      case CompetitorSortMode.newest:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    return filtered;
  }

  Future<void> _handleDelete(BuildContext context, Competitor c) async {
    final confirmed = await _showConfirmDialog(context, c);
    if (!confirmed || !mounted) return;

    final result = await ref.read(deleteCompetitorProvider(c.id).future);
    if (!mounted) return;

    _showSnackBar(
      context,
      success: result,
      message: result ? '${c.name} removed successfully' : 'Failed to delete ${c.name}',
    );
  }

  Future<void> _handleQuickScan(BuildContext context, Competitor c) async {
    _showSnackBar(
      context,
      success: true,
      message: '🚀 AI Scan triggered for ${c.name}! Fetching data...',
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ref.invalidate(competitorsListProvider);
      }
    });
  }

  Future<bool> _showConfirmDialog(BuildContext context, Competitor c) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            child: GlassCard(
              padding: const EdgeInsets.all(28),
              animate: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.danger,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Delete Competitor',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  Text(
                    'Are you sure you want to remove this competitor?',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceVariant
                          : AppColors.lightSurfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                    child: Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface
                              : AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: c.faviconUrl != null
                              ? Image.network(c.faviconUrl!,
                                  errorBuilder: (_, __, ___) =>
                                      _FallbackAvatar(name: c.name))
                              : _FallbackAvatar(name: c.name),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (c.domain != null)
                              Text(
                                c.domain!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: isDark
                                          ? AppColors.darkSecondary
                                          : AppColors.lightSecondary,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.warning.withOpacity(0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: AppColors.warning, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'All ${c.productsCount} products and associated AI insights will be permanently deleted. This cannot be undone.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.warning,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: AppColors.dangerGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.danger.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Delete',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  void _navigateToDetails(BuildContext context, Competitor c) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompetitorAnalysisScreen(
          competitorId: c.id,
          competitorName: c.name,
        ),
      ),
    );
  }

  void _navigateToTrends(BuildContext context, Competitor c) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrendAnalysisScreen(
          competitorId: c.id,
          competitorName: c.name,
        ),
      ),
    );
  }

  void _showSnackBar(BuildContext context, {required bool success, required String message}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            success ? Icons.check_circle_rounded : Icons.error_rounded,
            color: success ? AppColors.success : AppColors.danger,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ]),
        backgroundColor: AppColors.darkSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showPremiumAddDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _PremiumAddDialog(ref: ref),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🎯 SORT MODES
// ═══════════════════════════════════════════════════════════
enum CompetitorSortMode {
  recentlyScanned('Recently scanned', Icons.schedule_rounded),
  newest('Newest first', Icons.fiber_new_rounded),
  nameAsc('Name A → Z', Icons.sort_by_alpha_rounded),
  nameDesc('Name Z → A', Icons.sort_by_alpha_rounded),
  productsDesc('Most products', Icons.inventory_2_rounded);

  final String label;
  final IconData icon;
  const CompetitorSortMode(this.label, this.icon);
}

// ═══════════════════════════════════════════════════════════
// 🏠 SCREEN HEADER (TIER-AWARE)
// ═══════════════════════════════════════════════════════════
class _ScreenHeader extends StatelessWidget {
  final VoidCallback onAdd;
  final int competitorCount;
  const _ScreenHeader({required this.onAdd, required this.competitorCount});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.darkAccent.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.storefront_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Competitors',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                        color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Monitor & analyze your market rivals',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PlanUsageChip(count: competitorCount),
                  ],
                ),
              ]),
            ),
            GradientButton(
              text: 'Add Competitor''free';
        final max = TierRepository.getMaxCompetitors(tier);
        final isLimited = count >= max;
        final color = isLimited ? AppColors.warning : AppColors.darkAccent;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              tier == 'free' ? Icons.lock_outline : Icons.diamond_outlined,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              '${tier.toUpperCase()} • $count/$max slots',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🔍 SEARCH + SORT TOOLBAR
// ═══════════════════════════════════════════════════════════
class _SearchSortToolbar extends StatelessWidget {
  final TextEditingController searchController;
  final FocusNode focusNode;
  final CompetitorSortMode sortMode;
  final int resultsCount;
  final int totalCount;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<CompetitorSortMode> onSortChanged;

  const _SearchSortToolbar({
    required this.searchController,
    required this.focusNode,
    required this.sortMode,
    required this.resultsCount,
    required this.totalCount,
    required this.onSearchChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        final children = [
          Expanded(
            flex: isWide ? 3 : 1,
            child: _PremiumSearchBar(
              controller: searchController,
              focusNode: focusNode,
              onChanged: onSearchChanged,
              resultsCount: resultsCount,
              totalCount: totalCount,
            ),
          ),
          const SizedBox(width: 12),
          _SortDropdown(
            currentMode: sortMode,
            onChanged: onSortChanged,
          ),
        ];

        if (isWide) {
          return Row(children: children);
        }
        return Column(children: [
          _PremiumSearchBar(
            controller: searchController,
            focusNode: focusNode,
            onChanged: onSearchChanged,
            resultsCount: resultsCount,
            totalCount: totalCount,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: _SortDropdown(
              currentMode: sortMode,
              onChanged: onSortChanged,
            ),
          ),
        ]);
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🔍 PREMIUM SEARCH BAR
// ═══════════════════════════════════════════════════════════
class _PremiumSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final int resultsCount;
  final int totalCount;

  const _PremiumSearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.resultsCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasQuery = controller.text.isNotEmpty;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(children: [
        const SizedBox(width: 16),
        Icon(Icons.search_rounded,
            color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
            size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Search by name, website, or domain...',
              hintStyle: TextStyle(
                color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                fontSize: 15,
              ),
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        if (hasQuery)
          _ResultsCounter(
            current: resultsCount,
            total: totalCount,
          ),
        if (hasQuery)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Icon(Icons.close_rounded,
                    color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                    size: 18),
              ),
            ),
          )
        else
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '⌘ K',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                letterSpacing: 0.3,
              ),
            ),
          ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🔢 RESULTS COUNTER
// ═══════════════════════════════════════════════════════════
class _ResultsCounter extends StatelessWidget {
  final int current;
  final int total;
  const _ResultsCounter({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFiltered = current < total;
    final color = isFiltered
        ? AppColors.warning
        : (isDark ? AppColors.darkSecondary : AppColors.lightSecondary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$current / $total',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🎚️ SORT DROPDOWN
// ═══════════════════════════════════════════════════════════
class _SortDropdown extends StatelessWidget {
  final CompetitorSortMode currentMode;
  final ValueChanged<CompetitorSortMode> onChanged;

  const _SortDropdown({
    required this.currentMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuButton<CompetitorSortMode>(
      onSelected: onChanged,
      offset: const Offset(0, 52),
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      itemBuilder: (_) => CompetitorSortMode.values.map((mode) {
        return PopupMenuItem<CompetitorSortMode>(
          value: mode,
          child: Row(children: [
            Icon(mode.icon, size: 18,
                color: mode == currentMode
                    ? AppColors.darkAccent
                    : (isDark ? AppColors.darkSecondary : AppColors.lightSecondary)),
            const SizedBox(width: 12),
            Text(
              mode.label,
              style: TextStyle(
                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                fontWeight: mode == currentMode ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (mode == currentMode)
              const Icon(Icons.check_rounded, size: 16, color: AppColors.darkAccent),
          ]),
        );
      }).toList(),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(currentMode.icon, size: 18,
              color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 120),
            child: Text(
              currentMode.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.keyboard_arrow_down_rounded,
              color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 📊 ANIMATED STATS ROW
// ═══════════════════════════════════════════════════════════
class _AnimatedStatsRow extends StatelessWidget {
  final CompetitorStats stats;
  const _AnimatedStatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        final children = [
          _AnimatedStatChip(
            icon: Icons.storefront_rounded,
            label: 'Total',
            value: stats.total,
            color: AppColors.darkAccent,
          ),
          _AnimatedStatChip(
            icon: Icons.inventory_2_rounded,
            label: 'Products',
            value: stats.products,
            color: AppColors.success,
          ),
          _AnimatedStatChip(
            icon: Icons.check_circle_rounded,
            label: 'Scanned',
            value: stats.scannedThisWeek,
            color: AppColors.info,
            trend: stats.total > 0
                ? '${((stats.scannedThisWeek / stats.total) * 100).round()}%'
                : null,
            trendUp: stats.scannedThisWeek > 0,
          ),
          _AnimatedStatChip(
            icon: Icons.schedule_rounded,
            label: 'Pending',
            value: stats.pendingScan,
            color: AppColors.warning,
          ),
        ];

        if (isWide) {
          return Row(
            children: children
                .expand((e) => [Expanded(child: e), const SizedBox(width: 12)])
                .toList()
              ..removeLast(),
          );
        }
        return Wrap(spacing: 8, runSpacing: 8, children: children);
      },
    );
  }
}

class _AnimatedStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final String? trend;
  final bool trendUp;

  const _AnimatedStatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.trend,
    this.trendUp = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Text(label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                      fontWeight: FontWeight.w500,
                    )),
                if (trend != null) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: (trendUp ? AppColors.success : AppColors.danger)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(trend!,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: trendUp ? AppColors.success : AppColors.danger,
                        )),
                  ),
                ],
              ]),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: value),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, v, child) => Text(
                  v.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                    letterSpacing: 0.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _StatsLoading extends StatelessWidget {
  const _StatsLoading();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        4,
        (i) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 12),
            child: const ShimmerLoading(
              width: double.infinity,
              height: 52,
              borderRadius: 12,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🏪 COMPETITORS LIST
// ═══════════════════════════════════════════════════════════
class _CompetitorsList extends StatelessWidget {
  final List<Competitor> competitors;
  final void Function(Competitor) onDelete;
  final void Function(Competitor) onTap;
  final void Function(Competitor) onScan;
  final void Function(Competitor) onViewTrends;

  const _CompetitorsList({
    required this.competitors,
    required this.onDelete,
    required this.onTap,
    required this.onScan,
    required this.onViewTrends,
  });

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PremiumCompetitorCard(
              competitor: competitors[index],
              onDelete: () => onDelete(competitors[index]),
              onTap: () => onTap(competitors[index]),
              onScan: () => onScan(competitors[index]),
              onViewTrends: () => onViewTrends(competitors[index]),
            ),
          );
        },
        childCount: competitors.length,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 💎 PREMIUM COMPETITOR CARD
// ═══════════════════════════════════════════════════════════
class _PremiumCompetitorCard extends StatefulWidget {
  final Competitor competitor;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final VoidCallback onScan;
  final VoidCallback onViewTrends;

  const _PremiumCompetitorCard({
    required this.competitor,
    required this.onDelete,
    required this.onTap,
    required this.onScan,
    required this.onViewTrends,
  });

  @override
  State<_PremiumCompetitorCard> createState() => _PremiumCompetitorCardState();
}

class _PremiumCompetitorCardState extends State<_PremiumCompetitorCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = widget.competitor;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.008 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: GlassCard(
          padding: const EdgeInsets.all(20),
          onTap: widget.onTap,
          animate: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: c.faviconUrl != null
                        ? Image.network(c.faviconUrl!,
                            width: 56, height: 56,
                            errorBuilder: (_, __, ___) =>
                                _FallbackAvatar(name: c.name))
                        : _FallbackAvatar(name: c.name),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(
                            c.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(competitor: c),
                      ]),
                      const SizedBox(height: 4),
                      if (c.domain != null)
                        Row(children: [
                          Icon(Icons.link_rounded, size: 14,
                              color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(c.domain!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                    ],
                  ),
                ),
              ]),

              const SizedBox(height: 18),
              Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, height: 1),
              const SizedBox(height: 18),

              Row(children: [
                _InlineStat(
                  icon: Icons.inventory_2_rounded,
                  label: 'Products',
                  value: c.productsCount.toString(),
                  color: AppColors.info,
                ),
                const SizedBox(width: 20),
                _LastScanStat(competitor: c),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _hovering
                      ? _HoverActions(
                          key: const ValueKey('actions'),
                          onScan: widget.onScan,
                          onView: widget.onTap,
                          onViewTrends: widget.onViewTrends,
                          onDelete: widget.onDelete,
                        )
                      : const SizedBox.shrink(key: ValueKey('empty')),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ⏱️ LAST SCAN STAT WITH PROGRESS RING
// ═══════════════════════════════════════════════════════════
class _LastScanStat extends StatelessWidget {
  final Competitor competitor;
  const _LastScanStat({required this.competitor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final needsUrgent = competitor.needsUrgentScan;
    final color = needsUrgent ? AppColors.danger : AppColors.warning;

    double progress = 1.0;
    if (competitor.lastScanAt != null) {
      final daysAgo = DateTime.now().difference(competitor.lastScanAt!).inDays;
      progress = (1.0 - (daysAgo / 14)).clamp(0.0, 1.0);
    } else {
      progress = 0.0;
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 20,
        height: 20,
        child: Stack(children: [
          Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
          ),
          CustomPaint(
            painter: _RingPainter(progress: progress, color: color),
            size: const Size(20, 20),
          ),
        ]),
      ),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Last scan',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              )),
          Text(
            competitor.lastScanAt != null
                ? timeago.format(competitor.lastScanAt!)
                : 'Not scanned yet',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
            ),
          ),
        ],
      ),
    ]);
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      2 * 3.14159 * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ═══════════════════════════════════════════════════════════
// ⚡ HOVER ACTIONS (Scan, View, Trends, Delete)
// ═══════════════════════════════════════════════════════════
class _HoverActions extends StatelessWidget {
  final VoidCallback onScan;
  final VoidCallback onView;
  final VoidCallback onViewTrends;
  final VoidCallback onDelete;

  const _HoverActions({
    super.key,
    required this.onScan,
    required this.onView,
    required this.onViewTrends,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _ActionButton(
        icon: Icons.radar_rounded,
        tooltip: 'Trigger AI Scan',
        color: AppColors.success,
        onTap: onScan,
      ),
      const SizedBox(width: 8),
      _ActionButton(
        icon: Icons.auto_awesome_rounded,
        tooltip: 'View AI Insights',
        color: AppColors.info,
        onTap: onView,
      ),
      const SizedBox(width: 8),
      _ActionButton(
        icon: Icons.show_chart_rounded,
        tooltip: 'View Price Trends',
        color: AppColors.warning,
        onTap: onViewTrends,
      ),
      const SizedBox(width: 8),
      _ActionButton(
        icon: Icons.delete_outline_rounded,
        tooltip: 'Delete',
        color: AppColors.danger,
        onTap: onDelete,
      ),
    ]);
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🏷️ STATUS BADGE
// ═══════════════════════════════════════════════════════════
class _StatusBadge extends StatelessWidget {
  final Competitor competitor;
  const _StatusBadge({required this.competitor});

  @override
  Widget build(BuildContext context) {
    if (competitor.needsUrgentScan) {
      return _Badge(label: 'URGENT', color: AppColors.danger);
    }
    if (competitor.isRecentlyScanned) {
      return _Badge(label: 'FRESH', color: AppColors.success);
    }
    return _Badge(label: 'ACTIVE', color: AppColors.info);
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            )),
      ]),
    );
  }
}

class _InlineStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InlineStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              )),
          Text(value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              ),
          ),
        ],
      ),
    ]);
  }
}

class _FallbackAvatar extends StatelessWidget {
  final String name;
  const _FallbackAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.all(Radius.circular(13)),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🕳️ EMPTY STATE
// ═══════════════════════════════════════════════════════════
class _EmptyCompetitorsState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyCompetitorsState({required this.onAdd});

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
                AppColors.darkAccent.withOpacity(0.15),
                AppColors.purple.withOpacity(0.1),
              ]),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.darkAccent.withOpacity(0.4),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(Icons.storefront_rounded,
                color: Colors.white, size: 40),
          ),
        ]),
        const SizedBox(height: 32),
        Text('No competitors yet',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                )),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Text(
            'Add your first competitor to start tracking their products, prices, and strategic AI insights automatically.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                  height: 1.6,
                ),
          ),
        ),
        const SizedBox(height: 36),
        GradientButton(
          text: 'Add Your First Competitor',
          icon: Icons.add_rounded,
          height: 52,
          onPressed: onAdd,
        ),
        const SizedBox(height: 28),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 24,
          runSpacing: 12,
          children: [
            _FeatureHint(icon: Icons.radar_rounded, text: 'Automated AI Scraping'),
            _FeatureHint(icon: Icons.auto_awesome_rounded, text: 'Deep Strategy Analysis'),
            _FeatureHint(icon: Icons.trending_up_rounded, text: 'Real-time Price Tracking'),
          ],
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🔍 NO RESULTS STATE
// ═══════════════════════════════════════════════════════════
class _NoResultsState extends StatelessWidget {
  final String query;
  final VoidCallback onClear;

  const _NoResultsState({required this.query, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
        animate: false,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.search_off_rounded,
                color: AppColors.warning, size: 32),
          ),
          const SizedBox(height: 20),
          Text('No competitors found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 8),
          Text(
            'No results for "$query"',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkSecondary
                      : AppColors.lightSecondary,
                ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear_rounded, size: 18),
            label: const Text('Clear search'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _FeatureHint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14,
          color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary),
      const SizedBox(width: 6),
      Text(text,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
            fontWeight: FontWeight.w500,
          )),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════
// ⏳ LOADING STATE
// ═══════════════════════════════════════════════════════════
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 60),
          const ShimmerLoading(width: 200, height: 32, borderRadius: 10),
          const SizedBox(height: 12),
          const ShimmerLoading(width: 120, height: 16, borderRadius: 8),
          const SizedBox(height: 32),
          const ShimmerLoading(width: double.infinity, height: 52, borderRadius: 14),
          const SizedBox(height: 32),
          ...List.generate(
            4,
            (i) => Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: ShimmerLoading(
                width: double.infinity,
                height: 140,
                borderRadius: 20,
              ),
            ),
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
              Text('Failed to load competitors',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
              const SizedBox(height: 8),
              Text(error,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkSecondary
                            : AppColors.lightSecondary,
                      ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
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
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ➕ PREMIUM ADD DIALOG
// ═══════════════════════════════════════════════════════════
class _PremiumAddDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _PremiumAddDialog({required this.ref});

  @override
  ConsumerState<_PremiumAddDialog> createState() => _PremiumAddDialogState();
}

class _PremiumAddDialogState extends ConsumerState<_PremiumAddDialog> {
  final _nameCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _shopifyCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _websiteCtrl.dispose();
    _shopifyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await widget.ref.read(addCompetitorProvider(AddCompetitorParams(
        name: _nameCtrl.text.trim(),
        website: _websiteCtrl.text.trim().isNotEmpty ? _websiteCtrl.text.trim() : null,
        shopifyStore: _shopifyCtrl.text.trim().isNotEmpty ? _shopifyCtrl.text.trim() : null,
      )).future);

      if (!mounted) return;

      if (result) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.success, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${_nameCtrl.text.trim()} added! AI Scraper will analyze it shortly.',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
            ]),
            backgroundColor: AppColors.darkSurface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        setState(() => _error = 'Failed to add competitor. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: GlassCard(
          padding: const EdgeInsets.all(28),
          animate: false,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.darkAccent.withOpacity(0.3),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add_business_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Add Competitor',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          Text('Track products, prices & AI insights',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: isDark
                                        ? AppColors.darkSecondary
                                        : AppColors.lightSecondary,
                                  )),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded,
                          color: isDark
                              ? AppColors.darkSecondary
                              : AppColors.lightSecondary),
                    ),
                  ]),
                  const SizedBox(height: 28),
                  _PremiumTextField(
                    controller: _nameCtrl,
                    label: 'Competitor Name',
                    hint: 'e.g., Allbirds',
                    icon: Icons.business_rounded,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 18),
                  _PremiumTextField(
                    controller: _websiteCtrl,
                    label: 'Website',
                    hint: 'https://allbirds.com',
                    icon: Icons.language_rounded,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 18),
                  _PremiumTextField(
                    controller: _shopifyCtrl,
                    label: 'Shopify Store URL (optional)',
                    hint: 'https://store.myshopify.com',
                    icon: Icons.store_rounded,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.info.withOpacity(0.2)),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.auto_awesome_rounded,
                          color: AppColors.info, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Our AI will auto-detect the platform (Shopify, WooCommerce, etc.) and generate strategic insights automatically upon first scan.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.info,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ]),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppColors.danger, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: AppColors.danger, fontSize: 13)),
                        ),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _isLoading ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: GradientButton(
                          text: _isLoading ? 'Adding...' : 'Add Competitor',
                          icon: _isLoading ? null : Icons.check_rounded,
                          isLoading: _isLoading,
                          onPressed: _submit,
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _PremiumTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              letterSpacing: 0.1,
            )),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          enableSuggestions: false,
          autocorrect: false,
          autofillHints: const [],
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
              fontSize: 14,
            ),
            prefixIcon: Icon(icon,
                size: 18,
                color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor:
                isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.darkAccent, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.danger),
            ),
          ),
        ),
      ],
    );
  }
}
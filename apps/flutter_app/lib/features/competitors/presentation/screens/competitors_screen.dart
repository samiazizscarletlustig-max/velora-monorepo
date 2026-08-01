import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../shared/widgets/velora_card.dart';
import '../providers/competitors_providers.dart';
import '../../data/competitors_repository.dart';

class CompetitorsScreen extends ConsumerStatefulWidget {
  const CompetitorsScreen({super.key});

  @override
  ConsumerState<CompetitorsScreen> createState() => _CompetitorsScreenState();
}

class _CompetitorsScreenState extends ConsumerState<CompetitorsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statsAsync = ref.watch(competitorsStatsProvider);
    final filteredCompetitors = ref.watch(filteredCompetitorsProvider);
    final allCompetitorsAsync = ref.watch(competitorsListProvider);

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
                      'competitors.title'.tr(),
                      style: theme.textTheme.displayLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'competitors.subtitle'.tr(),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddCompetitorDialog(context),
                  icon: const Icon(Icons.add),
                  label: Text('competitors.add_new'.tr()),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ═══ Search Bar ═══
            VeloraCard(
              padding: EdgeInsets.zero,
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  ref.read(searchQueryProvider.notifier).state = value;
                },
                decoration: InputDecoration(
                  hintText: 'competitors.search_hint'.tr(),
                  prefixIcon: Icon(
                    Icons.search,
                    color: theme.colorScheme.secondary,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(searchQueryProvider.notifier).state = '';
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
            const SizedBox(height: 24),

            // ═══ Stats Grid ═══
            statsAsync.when(
              data: (stats) => _StatsGrid(stats: stats),
              loading: () => const _StatsGridLoading(),
              error: (error, _) => _ErrorCard(error: error.toString()),
            ),
            const SizedBox(height: 32),

            // ═══ Competitors List ═══
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'competitors.all_competitors'.tr(),
                  style: theme.textTheme.titleLarge,
                ),
                allCompetitorsAsync.whenOrNull(
                      data: (data) => Text(
                        '${filteredCompetitors.length} / ${data.length}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ) ??
                    const SizedBox.shrink(),
              ],
            ),
            const SizedBox(height: 16),

            // ═══ Competitors Cards ═══
            allCompetitorsAsync.when(
              data: (_) {
                if (filteredCompetitors.isEmpty) {
                  return _EmptyState(
                    hasSearch: _searchController.text.isNotEmpty,
                    onAdd: () => _showAddCompetitorDialog(context),
                  );
                }
                return Column(
                  children: filteredCompetitors
                      .map<Widget>(
                        (competitor) => _CompetitorCard(
                          competitor: competitor,
                          onDelete: () => _deleteCompetitor(competitor.id),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const _CompetitorsListLoading(),
              error: (error, _) => _ErrorCard(error: error.toString()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCompetitor(String id) async {
    // تأكيد الحذف
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('competitors.delete_title'.tr()),
        content: Text('competitors.delete_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(deleteCompetitorProvider(id).future);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('competitors.deleted_success'.tr())),
        );
      }
    }
  }

  void _showAddCompetitorDialog(BuildContext context) {
    final nameController = TextEditingController();
    final websiteController = TextEditingController();
    final shopifyController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('competitors.add_new'.tr()),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'competitors.name'.tr(),
                  hintText: 'Gymshark',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: websiteController,
                decoration: InputDecoration(
                  labelText: 'competitors.website'.tr(),
                  hintText: 'https://gymshark.com',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: shopifyController,
                decoration: InputDecoration(
                  labelText: 'competitors.shopify_store'.tr(),
                  hintText: 'gymshark.myshopify.com',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;

              Navigator.pop(dialogContext);

              await ref.read(
                addCompetitorProvider(
                  AddCompetitorParams(
                    name: nameController.text.trim(),
                    website: websiteController.text.trim().isEmpty
                        ? null
                        : websiteController.text.trim(),
                    shopifyStore: shopifyController.text.trim().isEmpty
                        ? null
                        : shopifyController.text.trim(),
                  ),
                ).future,
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('competitors.added_success'.tr())),
                );
              }
            },
            child: Text('common.add'.tr()),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Competitor Card Widget
// ═══════════════════════════════════════════

class _CompetitorCard extends StatelessWidget {
  final Competitor competitor;
  final VoidCallback onDelete;

  const _CompetitorCard({
    required this.competitor,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: VeloraCard(
        child: Row(
          children: [
            // Logo / Avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: competitor.logoUrl != null &&
                      competitor.logoUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        competitor.logoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.store, size: 28),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        competitor.name.isNotEmpty
                            ? competitor.name[0].toUpperCase()
                            : '?',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: const Color(0xFF4F46E5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    competitor.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.shopping_bag_outlined,
                        label: '${competitor.productsCount} products',
                      ),
                      const SizedBox(width: 12),
                      _InfoChip(
                        icon: Icons.schedule,
                        label: competitor.lastScanFormatted,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              color: const Color(0xFFEF4444),
              tooltip: 'common.delete'.tr(),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: theme.colorScheme.secondary,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.secondary,
          ),
        ),
      ],
    );
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
              icon: Icons.storefront_outlined,
              title: 'competitors.total'.tr(),
              value: stats['total'].toString(),
              color: const Color(0xFF4F46E5),
            ),
            _StatCard(
              icon: Icons.shopping_bag_outlined,
              title: 'competitors.products'.tr(),
              value: stats['products'].toString(),
              color: const Color(0xFF10B981),
            ),
            _StatCard(
              icon: Icons.check_circle_outline,
              title: 'competitors.scanned_week'.tr(),
              value: stats['scannedThisWeek'].toString(),
              color: const Color(0xFFF59E0B),
            ),
            _StatCard(
              icon: Icons.pending_actions,
              title: 'competitors.pending'.tr(),
              value: stats['pendingScan'].toString(),
              color: const Color(0xFFEF4444),
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
  final bool hasSearch;
  final VoidCallback onAdd;

  const _EmptyState({
    required this.hasSearch,
    required this.onAdd,
  });

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
                hasSearch ? Icons.search_off : Icons.storefront_outlined,
                size: 64,
                color: theme.colorScheme.secondary.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                hasSearch
                    ? 'competitors.no_results'.tr()
                    : 'competitors.empty_title'.tr(),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                hasSearch
                    ? 'competitors.try_different_search'.tr()
                    : 'competitors.empty_subtitle'.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (!hasSearch) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: Text('competitors.add_first'.tr()),
                ),
              ],
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

class _CompetitorsListLoading extends StatelessWidget {
  const _CompetitorsListLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: VeloraCard(
            child: SizedBox(
              height: 80,
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
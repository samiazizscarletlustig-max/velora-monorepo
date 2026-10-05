import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/insights_repository.dart';

// ═══════════════════════════════════════════
// Repository Provider
// ═══════════════════════════════════════════

/// Provider للـ Repository (Singleton)
final insightsRepositoryProvider = Provider<InsightsRepository>((ref) {
  return InsightsRepository();
});

// ═══════════════════════════════════════════
// Data Providers
// ═══════════════════════════════════════════

/// Provider لجلب كل الـ Insights — tier-filtered.
///
/// ✅ CHANGED: `getAll()` → `getAllForCurrentUser()`.
/// This single change activates all the tier-gating logic we built into
/// `AIInsight.isVisibleForTier(userTier)`:
///   - Free users see common insights + the stockout teaser.
///   - Pro / Pro Plus / Enterprise users see every Pro-only insight
///     (quick_wins, financial_blueprint, vulnerability_analysis, etc.)
///     and do NOT see the Free-only teaser.
///
/// `insightsStatsProvider` is automatically tier-filtered too, because
/// `repository.getStats()` now calls `getAllForCurrentUser()` internally.
final insightsListProvider = FutureProvider<List<AIInsight>>((ref) async {
  final repository = ref.watch(insightsRepositoryProvider);
  return repository.getAllForCurrentUser();
});

/// Provider لإحصائيات الـ Insights (tier-filtered internally)
final insightsStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repository = ref.watch(insightsRepositoryProvider);
  return repository.getStats();
});

// ═══════════════════════════════════════════
// Filter & Search Providers
// ═══════════════════════════════════════════

/// Severity filter (null = all)
final severityFilterProvider = StateProvider<String?>((ref) => null);

/// Search query
final insightsSearchQueryProvider = StateProvider<String>((ref) => '');

/// Filtered insights (based on severity + search, on top of tier filtering)
final filteredInsightsProvider = Provider<List<AIInsight>>((ref) {
  final insightsAsync = ref.watch(insightsListProvider);
  final severityFilter = ref.watch(severityFilterProvider);
  final searchQuery = ref.watch(insightsSearchQueryProvider).toLowerCase();

  return insightsAsync.whenOrNull(
        data: (insights) {
          var filtered = insights;

          // Filter by severity
          if (severityFilter != null) {
            filtered = filtered.where((i) => i.severity == severityFilter).toList();
          }

          // Filter by search query
          if (searchQuery.isNotEmpty) {
            filtered = filtered.where((i) {
              final title = i.title.toLowerCase();
              final summary = i.summary.toLowerCase();
              final competitor = (i.competitorName ?? '').toLowerCase();
              return title.contains(searchQuery) ||
                     summary.contains(searchQuery) ||
                     competitor.contains(searchQuery);
            }).toList();
          }

          return filtered;
        },
      ) ??
      [];
});

// ═══════════════════════════════════════════
// Action Providers
// ═══════════════════════════════════════════

/// Provider لحذف Insight
final deleteInsightProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, id) async {
  final repository = ref.read(insightsRepositoryProvider);
  final result = await repository.deleteInsight(id);

  if (result) {
    // Refresh the list after successful deletion
    ref.invalidate(insightsListProvider);
    ref.invalidate(insightsStatsProvider);
  }
  return result;
});
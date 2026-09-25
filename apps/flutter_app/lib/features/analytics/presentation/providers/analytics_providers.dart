import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/analytics_repository.dart';

// ═══════════════════════════════════════════
// Repository Provider
// ═══════════════════════════════════════════

/// Provider للـ Repository (Singleton)
final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository();
});

// ═══════════════════════════════════════════
// Data Providers
// ═══════════════════════════════════════════

/// Provider للإحصائيات العامة (4 بطاقات)
final analyticsStatsProvider = FutureProvider<AnalyticsStats>((ref) async {
  final repository = ref.watch(analyticsRepositoryProvider);
  return repository.getStats();
});

/// Provider لتوزيع الـ Insights (Pie Chart 🥧)
final insightsDistributionProvider = FutureProvider<List<PieSlice>>((ref) async {
  final repository = ref.watch(analyticsRepositoryProvider);
  return repository.getInsightsDistribution();
});

/// Provider للـ Timeline (Line Chart 📈)
final insightsTimelineProvider = FutureProvider<List<ChartDataPoint>>((ref) async {
  final repository = ref.watch(analyticsRepositoryProvider);
  return repository.getInsightsTimeline();
});

/// Provider لأفضل المنافسين (Bar Chart 📊)
final topCompetitorsProvider = FutureProvider<List<ChartDataPoint>>((ref) async {
  final repository = ref.watch(analyticsRepositoryProvider);
  return repository.getTopCompetitors();
});

// ═══════════════════════════════════════════
// Refresh Provider (لإعادة تحميل كل البيانات)
// ═══════════════════════════════════════════

/// Provider لإعادة تحميل كل بيانات Analytics
final refreshAnalyticsProvider = Provider<void Function(WidgetRef)>((ref) {
  return (WidgetRef ref) {
    ref.invalidate(analyticsStatsProvider);
    ref.invalidate(insightsDistributionProvider);
    ref.invalidate(insightsTimelineProvider);
    ref.invalidate(topCompetitorsProvider);
  };
});
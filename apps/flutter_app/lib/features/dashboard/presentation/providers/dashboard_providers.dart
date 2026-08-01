import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/dashboard_repository.dart';

/// Provider للـ Repository
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository();
});

/// Provider للإحصائيات (Async للتعامل مع Loading/Error)
final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  return repository.getStats();
});

/// Provider لآخر Insights
final recentInsightsProvider = FutureProvider<List<InsightPreview>>((ref) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  return repository.getRecentInsights(limit: 5);
});
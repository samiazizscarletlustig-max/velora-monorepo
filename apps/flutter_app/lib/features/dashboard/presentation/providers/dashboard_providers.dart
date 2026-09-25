import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/dashboard_repository.dart';

// ═══════════════════════════════════════════════════════════
// 🎯 DASHBOARD PROVIDERS — PERFECTION EDITION
// Reactive state management for dashboard data.
// ═══════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════
// 🏛️ REPOSITORY PROVIDER (Singleton)
// ═══════════════════════════════════════════════════════════
/// Singleton provider للـ DashboardRepository
/// keepAlive: true يضمن بقاء الـ repository حياً طوال عمر التطبيق
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  _logInfo('dashboardRepositoryProvider', 'Creating repository instance');
  
  ref.onDispose(() {
    _logInfo('dashboardRepositoryProvider', 'Disposing repository');
  });
  
  return DashboardRepository();
});

// ═══════════════════════════════════════════════════════════
// 📊 STATS PROVIDER
// ═══════════════════════════════════════════════════════════
/// Provider للإحصائيات العامة (Competitors, Products, Insights, etc.)
/// يُستخدم في DashboardScreen لإظهار stat cards + system health
final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  _logInfo('dashboardStatsProvider', 'Loading dashboard stats...');
  
  final repository = ref.watch(dashboardRepositoryProvider);
  
  try {
    final stats = await repository.getStats();
    _logSuccess('dashboardStatsProvider', 
        'Stats loaded: ${stats.totalCompetitors} competitors, ${stats.totalProducts} products');
    return stats;
  } catch (e, stack) {
    _logError('dashboardStatsProvider', 'Failed to load stats: $e');
    if (kDebugMode) debugPrintStack(stackTrace: stack);
    rethrow; // Re-throw للتعامل معه في UI
  }
});

// ═══════════════════════════════════════════════════════════
// 💡 RECENT INSIGHTS PROVIDER
// ═══════════════════════════════════════════════════════════
/// Provider لآخر 5 Insights للعرض في Dashboard
/// يُستخدم في قائمة "Recent Insights"
final recentInsightsProvider = FutureProvider<List<InsightPreview>>((ref) async {
  _logInfo('recentInsightsProvider', 'Loading recent insights...');
  
  final repository = ref.watch(dashboardRepositoryProvider);
  
  try {
    final insights = await repository.getRecentInsights(limit: 5);
    _logSuccess('recentInsightsProvider', 
        'Loaded ${insights.length} insights');
    return insights;
  } catch (e, stack) {
    _logError('recentInsightsProvider', 'Failed to load insights: $e');
    if (kDebugMode) debugPrintStack(stackTrace: stack);
    rethrow;
  }
});

// ═══════════════════════════════════════════════════════════
// 🔄 REFRESH DASHBOARD PROVIDER
// ═══════════════════════════════════════════════════════════
/// Provider لتحديث كل بيانات الـ Dashboard (Stats + Insights)
/// يُستخدم عند الضغط على زر Refresh أو Pull-to-refresh
///
/// الاستخدام:
/// ```dart
/// await ref.read(refreshDashboardProvider.future);
/// ```
final refreshDashboardProvider = FutureProvider<bool>((ref) async {
  _logInfo('refreshDashboardProvider', 'Refreshing all dashboard data...');
  
  try {
    // Invalidate كل providers المتعلقة بالـ Dashboard
    // هذا سيجعل Riverpod يعيد تحميلها تلقائياً
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(recentInsightsProvider);
    
    // انتظار إعادة التحميل
    await ref.read(dashboardStatsProvider.future);
    await ref.read(recentInsightsProvider.future);
    
    _logSuccess('refreshDashboardProvider', 'Dashboard refreshed successfully');
    return true;
  } catch (e, stack) {
    _logError('refreshDashboardProvider', 'Refresh failed: $e');
    if (kDebugMode) debugPrintStack(stackTrace: stack);
    return false;
  }
});

// ═══════════════════════════════════════════════════════════
// 📊 DERIVED PROVIDERS (Computed stats)
// ═══════════════════════════════════════════════════════════
/// Provider لنسبة صحة النظام (0-100%)
/// يُشتق من dashboardStatsProvider
final systemHealthPercentProvider = Provider<double>((ref) {
  final statsAsync = ref.watch(dashboardStatsProvider);
  return statsAsync.when(
    data: (stats) => stats.scanHealthPercent,
    loading: () => 0.0,
    error: (_, __) => 0.0,
  );
});

/// Provider لمتوسط المنتجات لكل منافس
final avgProductsPerCompetitorProvider = Provider<double>((ref) {
  final statsAsync = ref.watch(dashboardStatsProvider);
  return statsAsync.when(
    data: (stats) => stats.avgProductsPerCompetitor,
    loading: () => 0.0,
    error: (_, __) => 0.0,
  );
});

/// Provider للتحقق من وجود critical insights
final hasCriticalInsightsProvider = Provider<bool>((ref) {
  final statsAsync = ref.watch(dashboardStatsProvider);
  return statsAsync.when(
    data: (stats) => stats.criticalInsights > 0,
    loading: () => false,
    error: (_, __) => false,
  );
});

// ═══════════════════════════════════════════════════════════
// 🛠️ HELPER FUNCTIONS (Production-safe logging)
// ═══════════════════════════════════════════════════════════
void _logInfo(String provider, String message) {
  if (kDebugMode) {
    debugPrint('📊 [$provider] $message');
  }
}

void _logSuccess(String provider, String message) {
  if (kDebugMode) {
    debugPrint('✅ [$provider] $message');
  }
}

void _logError(String provider, String message) {
  if (kDebugMode) {
    debugPrint('❌ [$provider] $message');
  }
}
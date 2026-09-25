import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/dashboard_repository.dart''dashboardRepositoryProvider', 'Creating repository instance');
  
  ref.onDispose(() {
    _logInfo('dashboardRepositoryProvider', 'Disposing repository''dashboardStatsProvider', 'Loading dashboard stats...');
  
  final repository = ref.watch(dashboardRepositoryProvider);
  
  try {
    final stats = await repository.getStats();
    _logSuccess('dashboardStatsProvider', 
        'Stats loaded: ${stats.totalCompetitors} competitors, ${stats.totalProducts} products');
    return stats;
  } catch (e, stack) {
    _logError('dashboardStatsProvider', 'Failed to load stats: $e''recentInsightsProvider', 'Loading recent insights...');
  
  final repository = ref.watch(dashboardRepositoryProvider);
  
  try {
    final insights = await repository.getRecentInsights(limit: 5);
    _logSuccess('recentInsightsProvider', 
        'Loaded ${insights.length} insights');
    return insights;
  } catch (e, stack) {
    _logError('recentInsightsProvider', 'Failed to load insights: $e''refreshDashboardProvider', 'Refreshing all dashboard data...''refreshDashboardProvider', 'Dashboard refreshed successfully');
    return true;
  } catch (e, stack) {
    _logError('refreshDashboardProvider', 'Refresh failed: $e''📊 [$provider] $message');
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
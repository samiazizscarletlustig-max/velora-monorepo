import 'package:supabase_flutter/supabase_flutter.dart';

/// Data class لإحصائيات الـ Dashboard
class DashboardStats {
  final int totalCompetitors;
  final int totalProducts;
  final int totalInsights;
  final int criticalInsights;
  final int priceChanges;

  DashboardStats({
    required this.totalCompetitors,
    required this.totalProducts,
    required this.totalInsights,
    required this.criticalInsights,
    required this.priceChanges,
  });

  factory DashboardStats.empty() => DashboardStats(
        totalCompetitors: 0,
        totalProducts: 0,
        totalInsights: 0,
        criticalInsights: 0,
        priceChanges: 0,
      );
}

/// Data class لعرض Insight مختصر في Dashboard
class InsightPreview {
  final String id;
  final String title;
  final String summary;
  final String severity;
  final DateTime createdAt;

  InsightPreview({
    required this.id,
    required this.title,
    required this.summary,
    required this.severity,
    required this.createdAt,
  });

  factory InsightPreview.fromMap(Map<String, dynamic> map) {
    return InsightPreview(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Untitled',
      summary: map['summary'] as String? ?? '',
      severity: map['severity'] as String? ?? 'low',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// Repository لجلب بيانات الـ Dashboard من Supabase
class DashboardRepository {
  final SupabaseClient _client;

  DashboardRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// جلب الإحصائيات العامة
  Future<DashboardStats> getStats() async {
    try {
      // جلب عدد المنافسين
      final competitorsResponse = await _client
          .from('competitors')
          .select('id')
          .limit(1000);
      final totalCompetitors = competitorsResponse.length;

      // جلب عدد المنتجات
      final productsResponse = await _client
          .from('products')
          .select('id')
          .limit(10000);
      final totalProducts = productsResponse.length;

      // جلب Insights
      final insightsResponse = await _client
          .from('ai_insights')
          .select('id, severity');
      
      final totalInsights = insightsResponse.length;
      final criticalInsights = insightsResponse
          .where((i) => 
            (i['severity'] as String?) == 'critical' || 
            (i['severity'] as String?) == 'high')
          .length;

      // ✅ الإصلاح: جلب إجمالي Price Changes (بدون فلتر التاريخ)
      // لأن عمود created_at قد لا يكون موجوداً في price_history
      int priceChanges = 0;
      try {
        final priceHistoryResponse = await _client
            .from('price_history')
            .select('id')
            .limit(10000);
        priceChanges = priceHistoryResponse.length;
      } catch (e) {
        print('⚠️ Price history query failed: $e');
        priceChanges = 0;
      }

      return DashboardStats(
        totalCompetitors: totalCompetitors,
        totalProducts: totalProducts,
        totalInsights: totalInsights,
        criticalInsights: criticalInsights,
        priceChanges: priceChanges,
      );
    } catch (e) {
      print('❌ Error getting dashboard stats: $e');
      return DashboardStats.empty();
    }
  }

  /// جلب آخر 5 Insights للعرض في Dashboard
  Future<List<InsightPreview>> getRecentInsights({int limit = 5}) async {
    try {
      final response = await _client
          .from('ai_insights')
          .select('id, title, summary, severity, created_at')
          .order('created_at', ascending: false)
          .limit(limit);

      return response
          .map((map) => InsightPreview.fromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error getting recent insights: $e');
      return [];
    }
  }
}
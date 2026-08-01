import 'package:supabase_flutter/supabase_flutter.dart';

// ═══════════════════════════════════════════
// Data Classes
// ═══════════════════════════════════════════

/// نقطة بيانات للرسم البياني (Line/Bar)
class ChartDataPoint {
  final DateTime date;
  final double value;
  final String? label;

  ChartDataPoint({
    required this.date,
    required this.value,
    this.label,
  });
}

/// قطاع في Pie Chart
class PieSlice {
  final String label;
  final double value;
  final String colorHex;

  PieSlice({
    required this.label,
    required this.value,
    required this.colorHex,
  });
}

/// بيانات إحصائيات Analytics العامة
class AnalyticsStats {
  final int totalCompetitors;
  final int totalProducts;
  final int totalInsights;
  final double avgProductsPerCompetitor;

  AnalyticsStats({
    required this.totalCompetitors,
    required this.totalProducts,
    required this.totalInsights,
    required this.avgProductsPerCompetitor,
  });

  factory AnalyticsStats.empty() => AnalyticsStats(
        totalCompetitors: 0,
        totalProducts: 0,
        totalInsights: 0,
        avgProductsPerCompetitor: 0,
      );
}

// ═══════════════════════════════════════════
// Repository
// ═══════════════════════════════════════════

/// Repository لجلب بيانات Analytics
class AnalyticsRepository {
  final SupabaseClient _client;

  AnalyticsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// جلب الإحصائيات العامة
  Future<AnalyticsStats> getStats() async {
    try {
      final competitors = await _client.from('competitors').select('id');
      final insights = await _client.from('ai_insights').select('id');
      
      // محاولة جلب المنتجات (قد لا يكون الجدول موجوداً)
      int productsCount = 0;
      try {
        final products = await _client.from('products').select('id');
        productsCount = products.length;
      } catch (e) {
        print('⚠️ Products table may not exist: $e');
      }

      final avgProducts = competitors.isEmpty
          ? 0.0
          : productsCount / competitors.length;

      return AnalyticsStats(
        totalCompetitors: competitors.length,
        totalProducts: productsCount,
        totalInsights: insights.length,
        avgProductsPerCompetitor: double.parse(avgProducts.toStringAsFixed(1)),
      );
    } catch (e) {
      print('❌ Error getting analytics stats: $e');
      return AnalyticsStats.empty();
    }
  }

  /// 📊 توزيع الـ Insights حسب Severity (Pie Chart)
  Future<List<PieSlice>> getInsightsDistribution() async {
    try {
      final insights = await _client.from('ai_insights').select('severity');

      // عد كل severity
      final counts = <String, int>{
        'critical': 0,
        'high': 0,
        'medium': 0,
        'low': 0,
      };

      for (final insight in insights) {
        final severity = (insight['severity'] as String? ?? 'low').toLowerCase();
        if (counts.containsKey(severity)) {
          counts[severity] = counts[severity]! + 1;
        }
      }

      // تحويل إلى PieSlice
      final colors = {
        'critical': 'EF4444',
        'high': 'F59E0B',
        'medium': '3B82F6',
        'low': '10B981',
      };

      return counts.entries
          .where((e) => e.value > 0)
          .map((e) => PieSlice(
                label: e.key[0].toUpperCase() + e.key.substring(1),
                value: e.value.toDouble(),
                colorHex: colors[e.key]!,
              ))
          .toList();
    } catch (e) {
      print('❌ Error getting insights distribution: $e');
      return [];
    }
  }

  /// 📈 Insights عبر الزمن (Line Chart - آخر 30 يوم)
  Future<List<ChartDataPoint>> getInsightsTimeline() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final insights = await _client
          .from('ai_insights')
          .select('created_at')
          .gte('created_at', thirtyDaysAgo.toIso8601String());

      // تجميع حسب اليوم
      final countsByDate = <String, int>{};
      for (final insight in insights) {
        final dateStr = insight['created_at'] as String;
        final date = DateTime.tryParse(dateStr);
        if (date != null) {
          final key = '${date.year}-${date.month}-${date.day}';
          countsByDate[key] = (countsByDate[key] ?? 0) + 1;
        }
      }

      // تحويل إلى ChartDataPoint
      final points = countsByDate.entries.map((e) {
        final parts = e.key.split('-');
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        return ChartDataPoint(
          date: date,
          value: e.value.toDouble(),
        );
      }).toList();

      // ترتيب حسب التاريخ
      points.sort((a, b) => a.date.compareTo(b.date));
      return points;
    } catch (e) {
      print('❌ Error getting insights timeline: $e');
      return [];
    }
  }

  /// 🏆 أفضل 5 منافسين (Bar Chart)
  Future<List<ChartDataPoint>> getTopCompetitors() async {
    try {
      final competitors = await _client.from('competitors').select('id, name');

      final results = <ChartDataPoint>[];
      
      for (final competitor in competitors.take(5)) {
        // حساب عدد المنتجات لكل منافس
        int productsCount = 0;
        try {
          final products = await _client
              .from('products')
              .select('id')
              .eq('competitor_id', competitor['id'] as String);
          productsCount = products.length;
        } catch (e) {
          // Products table may not exist
        }

        results.add(ChartDataPoint(
          date: DateTime.now(),
          value: productsCount.toDouble(),
          label: competitor['name'] as String? ?? 'Unknown',
        ));
      }

      // ترتيب من الأعلى للأقل
      results.sort((a, b) => b.value.compareTo(a.value));
      return results;
    } catch (e) {
      print('❌ Error getting top competitors: $e');
      return [];
    }
  }
}
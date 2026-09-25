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
        avgProductsPerCompetitor: 0.0,
      );
}

// ═══════════════════════════════════════════
// Repository
// ═══════════════════════════════════════════

/// Repository لجلب بيانات Analytics (معزولة تماماً للمستخدم الحالي)
class AnalyticsRepository {
  final SupabaseClient _client;

  AnalyticsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// الحصول على معرف المستخدم الحالي
  String? get _currentUserId => _client.auth.currentUser?.id;

  /// جلب الإحصائيات العامة (معزولة حسب المستخدم)
  Future<AnalyticsStats> getStats() async {
    final userId = _currentUserId;
    if (userId == null) return AnalyticsStats.empty();

    try {
      // 1. جلب منافسي المستخدم الحالي فقط
      final competitorsRes = await _client
          .from('competitors')
          .select('id')
          .eq('user_id', userId);

      final competitorIds = competitorsRes.map((c) => c['id'] as String).toList();
      final totalCompetitors = competitorIds.length;

      if (totalCompetitors == 0) {
        return AnalyticsStats.empty();
      }

      // 2. حساب المنتجات لهؤلاء المنافسين فقط (باستخدام length الآمن)
      final productsRes = await _client
          .from('products')
          .select('id')
          .inFilter('competitor_id', competitorIds);
      
      final totalProducts = productsRes.length;

      // 3. حساب الرؤى لهؤلاء المنافسين فقط
      final insightsRes = await _client
          .from('ai_insights')
          .select('id')
          .inFilter('competitor_id', competitorIds);
      
      final totalInsights = insightsRes.length;

      final avgProducts = totalCompetitors > 0 
          ? totalProducts / totalCompetitors 
          : 0.0;

      return AnalyticsStats(
        totalCompetitors: totalCompetitors,
        totalProducts: totalProducts,
        totalInsights: totalInsights,
        avgProductsPerCompetitor: double.parse(avgProducts.toStringAsFixed(1)),
      );
    } catch (e) {
      print('❌ Error getting analytics stats: $e');
      return AnalyticsStats.empty();
    }
  }

  /// 📊 توزيع الـ Insights حسب Severity (Pie Chart) - معزول للمستخدم
  Future<List<PieSlice>> getInsightsDistribution() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final competitorsRes = await _client
          .from('competitors')
          .select('id')
          .eq('user_id', userId);

      final competitorIds = competitorsRes.map((c) => c['id'] as String).toList();
      if (competitorIds.isEmpty) return [];

      final insights = await _client
          .from('ai_insights')
          .select('severity')
          .inFilter('competitor_id', competitorIds);

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

  /// 📈 Insights عبر الزمن (Line Chart - آخر 30 يوم) - معزول للمستخدم
  Future<List<ChartDataPoint>> getInsightsTimeline() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final competitorsRes = await _client
          .from('competitors')
          .select('id')
          .eq('user_id', userId);

      final competitorIds = competitorsRes.map((c) => c['id'] as String).toList();
      if (competitorIds.isEmpty) return [];

      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final insights = await _client
          .from('ai_insights')
          .select('created_at')
          .inFilter('competitor_id', competitorIds)
          .gte('created_at', thirtyDaysAgo.toIso8601String());

      final countsByDate = <String, int>{};
      for (final insight in insights) {
        final dateStr = insight['created_at'] as String;
        final date = DateTime.tryParse(dateStr);
        if (date != null) {
          final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          countsByDate[key] = (countsByDate[key] ?? 0) + 1;
        }
      }

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

      points.sort((a, b) => a.date.compareTo(b.date));
      return points;
    } catch (e) {
      print('❌ Error getting insights timeline: $e');
      return [];
    }
  }

  /// 🏆 أفضل 5 منافسين (Bar Chart) - معزول للمستخدم
  Future<List<ChartDataPoint>> getTopCompetitors() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final competitorsRes = await _client
          .from('competitors')
          .select('id, name')
          .eq('user_id', userId);

      final results = <ChartDataPoint>[];
      
      for (final competitor in competitorsRes) {
        final compId = competitor['id'] as String;
        final compName = competitor['name'] as String? ?? 'Unknown';

        // حساب عدد المنتجات لهذا المنافس تحديداً (باستخدام length الآمن)
        final productsRes = await _client
            .from('products')
            .select('id')
            .eq('competitor_id', compId);
        
        final productsCount = productsRes.length;

        results.add(ChartDataPoint(
          date: DateTime.now(),
          value: productsCount.toDouble(),
          label: compName,
        ));
      }

      // ترتيب من الأعلى للأقل وأخذ أفضل 5 فقط
      results.sort((a, b) => b.value.compareTo(a.value));
      return results.take(5).toList();
    } catch (e) {
      print('❌ Error getting top competitors: $e');
      return [];
    }
  }
}
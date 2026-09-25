import 'package:supabase_flutter/supabase_flutter.dart';

/// Data class للـ AI Insight
class AIInsight {
  final String id;
  final String title;
  final String summary;
  final String detailedAnalysis;
  final String aiRecommendation;  // ✅ أضفنا هذه الخاصية
  final String severity;
  final String? competitorName;
  final DateTime createdAt;

  AIInsight({
    required this.id,
    required this.title,
    required this.summary,
    this.detailedAnalysis = '',
    this.aiRecommendation = '',  // ✅ قيمة افتراضية
    required this.severity,
    this.competitorName,
    required this.createdAt,
  });

  factory AIInsight.fromMap(Map<String, dynamic> map) {
    return AIInsight(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Untitled Insight',
      summary: map['summary'] as String? ?? '',
      detailedAnalysis: map['detailed_analysis'] as String? ?? '',
      aiRecommendation: map['ai_recommendation'] as String? ?? '',  // ✅ أضفنا هذا
      severity: (map['severity'] as String? ?? 'low').toLowerCase(),
      competitorName: map['competitor_name'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  /// تنسيق التاريخ بالنسبي
  String get timeAgoFormatted {
    final diff = DateTime.now().difference(createdAt);
    
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${diff.inDays ~/ 7}w ago';
    }
  }

  /// لون Severity
  String get severityColor {
    switch (severity) {
      case 'critical':
        return 'EF4444';
      case 'high':
        return 'F59E0B';
      case 'medium':
        return '3B82F6';
      default:
        return '10B981';
    }
  }
}

/// Repository لجلب وإدارة AI Insights
class InsightsRepository {
  final SupabaseClient _client;

  InsightsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// جلب كل Insights (مع محاولة جلب اسم المنافس)
  Future<List<AIInsight>> getAll() async {
    try {
      List<Map<String, dynamic>> response;
      
      try {
        response = await _client
            .from('ai_insights')
            .select('*, competitors(name)')
            .order('created_at', ascending: false)
            .limit(100);
        
        return response.map((map) {
          final competitorData = map['competitors'] as Map<String, dynamic>?;
          return AIInsight.fromMap({
            ...map,
            'competitor_name': competitorData?['name'],
          });
        }).toList();
      } catch (e) {
        print('⚠️ Join failed, fetching insights without competitor names: $e');
        response = await _client
            .from('ai_insights')
            .select('*')
            .order('created_at', ascending: false)
            .limit(100);
        
        return response.map((map) => AIInsight.fromMap(map)).toList();
      }
    } catch (e) {
      print('❌ Error fetching insights: $e');
      return [];
    }
  }

  /// جلب Insights حسب Severity
  Future<List<AIInsight>> getBySeverity(String severity) async {
    try {
      final response = await _client
          .from('ai_insights')
          .select('*')
          .eq('severity', severity)
          .order('created_at', ascending: false)
          .limit(100);

      return response.map((map) => AIInsight.fromMap(map)).toList();
    } catch (e) {
      print('❌ Error fetching insights by severity: $e');
      return [];
    }
  }

  /// جلب الإحصائيات
  Future<Map<String, int>> getStats() async {
    try {
      final all = await _client.from('ai_insights').select('id');
      
      final critical = await _client
          .from('ai_insights')
          .select('id')
          .eq('severity', 'critical');
      
      final high = await _client
          .from('ai_insights')
          .select('id')
          .eq('severity', 'high');
      
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final thisWeek = await _client
          .from('ai_insights')
          .select('id')
          .gte('created_at', weekAgo.toIso8601String());

      return {
        'total': all.length,
        'critical': critical.length,
        'high': high.length,
        'thisWeek': thisWeek.length,
      };
    } catch (e) {
      print('❌ Error getting insights stats: $e');
      return {
        'total': 0,
        'critical': 0,
        'high': 0,
        'thisWeek': 0,
      };
    }
  }

  /// حذف Insight
  Future<bool> deleteInsight(String id) async {
    try {
      await _client.from('ai_insights').delete().eq('id', id);
      return true;
    } catch (e) {
      print('❌ Error deleting insight: $e');
      return false;
    }
  }
}
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ═══════════════════════════════════════════════════════════
// 🎯 DASHBOARD REPOSITORY — 100% BULLETPROOF EDITION
// ═══════════════════════════════════════════════════════════

int _safeInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

DateTime? _safeParseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }
  return null;
}

class DashboardException implements Exception {
  final String message;
  final String? code;
  final Object? cause;
  
  DashboardException(this.message, {this.code, this.cause});
  
  @override
  String toString() => 'DashboardException: $message${code != null ? ' ($code)' : ''}';
}

class DashboardStats {
  final int totalCompetitors;
  final int totalProducts;
  final int totalInsights;
  final int criticalInsights;
  final int priceChanges;

  const DashboardStats({
    required this.totalCompetitors,
    required this.totalProducts,
    required this.totalInsights,
    required this.criticalInsights,
    required this.priceChanges,
  });

  factory DashboardStats.empty() => const DashboardStats(
        totalCompetitors: 0,
        totalProducts: 0,
        totalInsights: 0,
        criticalInsights: 0,
        priceChanges: 0,
      );

  factory DashboardStats.fromMap(Map<String, dynamic> map) {
    return DashboardStats(
      totalCompetitors: _safeInt(map['totalCompetitors']),
      totalProducts: _safeInt(map['totalProducts']),
      totalInsights: _safeInt(map['totalInsights']),
      criticalInsights: _safeInt(map['criticalInsights']),
      priceChanges: _safeInt(map['priceChanges']),
    );
  }

  double get scanHealthPercent {
    if (totalCompetitors == 0) return 0.0;
    return ((totalCompetitors - criticalInsights) / totalCompetitors * 100).clamp(0, 100);
  }

  double get avgProductsPerCompetitor {
    if (totalCompetitors == 0) return 0.0;
    return totalProducts / totalCompetitors;
  }
}

class InsightPreview {
  final String id;
  final String title;
  final String summary;
  final String severity;
  final DateTime createdAt;
  final String? aiRecommendation;
  final String? competitorName;
  final String? linkedCompetitorId;

  const InsightPreview({
    required this.id,
    required this.title,
    required this.summary,
    required this.severity,
    required this.createdAt,
    this.aiRecommendation,
    this.competitorName,
    this.linkedCompetitorId,
  });

  factory InsightPreview.fromMap(Map<String, dynamic> map) {
    return InsightPreview(
      id: (map['id'] as String?) ?? '',
      title: (map['title'] as String?) ?? 'Untitled',
      summary: (map['summary'] as String?) ?? '',
      severity: (map['severity'] as String?)?.toLowerCase() ?? 'low',
      createdAt: _safeParseDate(map['created_at']) ?? DateTime.now(),
      aiRecommendation: map['ai_recommendation'] as String?,
      competitorName: map['competitor_name''linked_competitor_id'] ?? map['competitor_id']) as String?,
    );
  }

  String get timeAgoFormatted {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }
}

class DashboardRepository {
  final SupabaseClient _client;

  DashboardRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  String? _getUserId() => _client.auth.currentUser?.id;

  Future<DashboardStats> getStats() async {
    final userId = _getUserId();
    try {
      final results = await Future.wait([
        _countRows('competitors', userId: userId),
        _countRows('products', userId: userId),
        _countRows('ai_insights', userId: userId),
        _countCriticalInsights(userId: userId),
        _countPriceChanges(userId: userId),
      ]);

      return DashboardStats(
        totalCompetitors: results[0] as int,
        totalProducts: results[1] as int,
        totalInsights: results[2] as int,
        criticalInsights: results[3] as int,
        priceChanges: results[4] as int,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('❌ getStats error: $e');
      return DashboardStats.empty();
    }
  }

  Future<int> _countRows(String table, {String? userId}) async {
    try {
      final baseQuery = _client.from(table).select('id');
      final response = await (userId == null ? baseQuery : baseQuery.eq('user_id', userId));
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _countCriticalInsights({String? userId}) async {
    try {
      final baseQuery = _client.from('ai_insights').select('id');
      final response = await (userId == null
          ? baseQuery.inFilter('severity', ['critical', 'high'])
          : baseQuery.eq('user_id', userId).inFilter('severity', ['critical', 'high']));
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _countPriceChanges({String? userId}) async {
    try {
      final baseQuery = _client.from('price_history').select('id');
      final response = await (userId == null ? baseQuery : baseQuery.eq('user_id''ai_insights').select('''
            id, title, summary, severity, created_at, ai_recommendation, competitor_id,
            competitors:competitor_id ( name )
          ''');

      final filteredQuery = userId == null 
          ? baseQuery 
          : baseQuery.eq('user_id', userId);

      final response = await filteredQuery.order('created_at', ascending: false).limit(limit);

      if (response is! List) return [];

      return response.map((raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        String? competitorName;
        if (map['competitors'] != null) {
          final comp = map['competitors'];
          if (comp is Map) {
            competitorName = comp['name'] as String?;
          } else if (comp is List && comp.isNotEmpty && comp.first is Map) {
            competitorName = (comp.first as Map)['name'] as String?;
          }
        }
        map.remove('competitors');
        map['competitor_name'] = competitorName;
        
        return InsightPreview.fromMap(map);
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ getRecentInsights error: $e');
      return [];
    }
  }

  void _logInfo(String method, String message) {
    if (kDebugMode) debugPrint('✅ [DashboardRepository.$method] $message');
  }

  void _logWarning(String method, String message) {
    if (kDebugMode) debugPrint('⚠️ [DashboardRepository.$method] $message');
  }

  void _logError(String method, String message) {
    if (kDebugMode) debugPrint('❌ [DashboardRepository.$method] $message');
  }
}
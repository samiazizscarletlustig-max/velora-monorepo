import 'package:supabase_flutter/supabase_flutter.dart';

/// Data class للـ AI Insight
class AIInsight {
  final String id;
  final String type; // ✅ NEW: insight type (chart_bundle, quick_wins, etc.)
  final String title;
  final String summary;
  final String detailedAnalysis;
  final String aiRecommendation;
  final String severity;
  final String? competitorName;
  final DateTime createdAt;

  AIInsight({
    required this.id,
    this.type = 'general', // ✅ default for backward compat
    required this.title,
    required this.summary,
    this.detailedAnalysis = '',
    this.aiRecommendation = '',
    required this.severity,
    this.competitorName,
    required this.createdAt,
  });

  factory AIInsight.fromMap(Map<String, dynamic> map) {
    return AIInsight(
      id: map['id'] as String,
      type: (map['type'] as String? ?? 'general').toLowerCase(), // ✅ NEW
      title: map['title'] as String? ?? 'Untitled Insight',
      summary: map['summary'] as String? ?? '',
      detailedAnalysis: map['detailed_analysis'] as String? ?? '',
      aiRecommendation: map['ai_recommendation'] as String? ?? '',
      severity: (map['severity'] as String? ?? 'low').toLowerCase(),
      competitorName: map['competitor_name'] as String?,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🆕 TIER GATING HELPERS
  // ═══════════════════════════════════════════════════════════

  /// Insight types that are ONLY visible to Pro / Pro Plus / Enterprise users.
  /// Free users should NOT see these (they are the Pro upsell).
  static const Set<String> _proOnlyTypes = {
    'out_of_stock_signal',
    'vulnerability_analysis',
    'financial_blueprint',
    'quick_wins',
    'strategic_timeline',
    'cross_reference',
  };

  /// True if this insight is gated behind the Pro tier.
  bool get isProOnly => _proOnlyTypes.contains(type);

  /// The stockout_signal_teaser card is shown ONLY to Free users — it's a
  /// teaser designed to convince them to upgrade. Pro users should never see it.
  bool get isFreeTeaser => type == 'stockout_signal_teaser';

  /// True if a user on [userTier] is allowed to view this insight.
  bool isVisibleForTier(String userTier) {
    final tier = userTier.toLowerCase();
    final isPro =
        tier == 'pro' || tier == 'pro_plus' || tier == 'enterprise';

    if (isFreeTeaser) {
      // Teaser only for Free users — hides once they upgrade.
      return !isPro;
    }
    if (isProOnly) {
      // Pro-only insights hide from Free users.
      return isPro;
    }
    // Common insights (executive_summary, product_gap, chart_bundle, etc.)
    // are visible to everyone.
    return true;
  }

  // ═══════════════════════════════════════════════════════════
  // FORMATTING HELPERS
  // ═══════════════════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════════════════
  // 🆕 USER TIER
  // ═══════════════════════════════════════════════════════════

  /// Returns the currently logged-in user's tier ('free' | 'pro' | 'pro_plus' | 'enterprise').
  /// Falls back to 'free' if anything goes wrong — so Free users never accidentally
  /// see Pro-only content because of a DB failure.
  Future<String> getCurrentUserTier() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return 'free';

      final response = await _client
          .from('users')
          .select('tier')
          .eq('id', user.id)
          .maybeSingle();

      final tier = (response?['tier'] as String?)?.toLowerCase();
      return tier ?? 'free';
    } catch (e) {
      print('⚠️ Could not fetch user tier, defaulting to free: $e');
      return 'free';
    }
  }

  // ═══════════════════════════════════════════════════════════
  // FETCH INSIGHTS
  // ═══════════════════════════════════════════════════════════

  /// Fetch ALL insights (no tier filtering). Use this for admin/debug views
  /// or for downstream methods that do their own filtering.
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

  /// 🆕 MAIN METHOD: Returns only the insights the current user is allowed
  /// to see based on their subscription tier.
  ///
  /// - Pro / Pro Plus / Enterprise users see every Pro-only insight and all
  ///   common insights; the Free-only teaser is filtered out.
  /// - Free users see common insights + the Free teaser; Pro-only insights
  ///   are filtered out.
  Future<List<AIInsight>> getAllForCurrentUser() async {
    final all = await getAll();
    if (all.isEmpty) return const [];

    final userTier = await getCurrentUserTier();

    return all.where((i) => i.isVisibleForTier(userTier)).toList();
  }

  /// Fetch insights filtered by severity (uses current-user tier filtering).
  Future<List<AIInsight>> getBySeverity(String severity) async {
    final allForUser = await getAllForCurrentUser();
    return allForUser
        .where((i) => i.severity.toLowerCase() == severity.toLowerCase())
        .toList();
  }

  // ═══════════════════════════════════════════════════════════
  // STATS
  // ═══════════════════════════════════════════════════════════

  /// Stats are computed on the TIER-FILTERED list so the header badges
  /// always reflect what the current user actually sees.
  Future<Map<String, int>> getStats() async {
    try {
      final insights = await getAllForCurrentUser();

      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

      return {
        'total': insights.length,
        'critical': insights.where((i) => i.severity == 'critical').length,
        'high': insights.where((i) => i.severity == 'high').length,
        'thisWeek': insights
            .where((i) => i.createdAt.isAfter(weekAgo))
            .length,
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
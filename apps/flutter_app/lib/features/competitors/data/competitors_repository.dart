import 'package:supabase_flutter/supabase_flutter.dart';

/// Data class للمنافس
class Competitor {
  final String id;
  final String name;
  final String? website;
  final String? logoUrl;
  final String? shopifyStore;
  final String userId; // ✅ مطلوب لعزل البيانات
  final DateTime createdAt;
  final DateTime? lastScanAt;
  final int productsCount;

  Competitor({
    required this.id,
    required this.name,
    this.website,
    this.logoUrl,
    this.shopifyStore,
    required this.userId,
    required this.createdAt,
    this.lastScanAt,
    this.productsCount = 0,
  });

  factory Competitor.fromMap(Map<String, dynamic> map) {
    return Competitor(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Unknown',
      website: map['website'] as String?,
      logoUrl: map['logo_url'] as String?,
      shopifyStore: map['shopify_store'] as String?,
      userId: map['user_id'] as String,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      lastScanAt: DateTime.tryParse(map['last_scan_at'] as String? ?? ''),
      productsCount: (map['products_count'] as int?) ?? 0,
    );
  }

  /// تنسيق "last scan" بالنسبي
  String get lastScanFormatted {
    if (lastScanAt == null) return 'Never scanned';

    final diff = DateTime.now().difference(lastScanAt!);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${diff.inDays ~/ 7}w ago';
  }
}

/// Repository لإدارة المنافسين + scraping
class CompetitorsRepository {
  final SupabaseClient _client;

  CompetitorsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // ═══════════════════════════════════════════════════════
  // جلب كل منافسي المستخدم الحالي (مع عدد منتجاتهم)
  // ═══════════════════════════════════════════════════════
  Future<List<Competitor>> getAll({required String userId}) async {
    try {
      final response = await _client
          .from('competitors')
          .select('*')
          .eq('user_id', userId) // ✅ عزل بالمستخدم
          .order('created_at', ascending: false);

      final competitors = <Competitor>[];

      for (final map in response) {
        int productsCount = 0;
        try {
          final products = await _client
              .from('products')
              .select('id')
              .eq('competitor_id', map['id'] as String);
          productsCount = products.length;
        } catch (e) {
          print('⚠️ Could not count products for ${map['id']}: $e');
          productsCount = 0;
        }

        competitors.add(Competitor.fromMap({
          ...map,
          'products_count': productsCount,
        }));
      }

      return competitors;
    } catch (e) {
      print('❌ Error fetching competitors: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════
  // إضافة منافس جديد
  // ═══════════════════════════════════════════════════════
  Future<Competitor?> addCompetitor({
    required String name,
    required String userId,
    String? website,
    String? shopifyStore,
  }) async {
    try {
      final response = await _client
          .from('competitors')
          .insert({
            'name': name.trim(),
            'website': website,
            'shopify_store': shopifyStore,
            'user_id': userId,
          })
          .select()
          .single();

      return Competitor.fromMap(response);
    } catch (e) {
      print('❌ Error adding competitor: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════
  // حذف منافس (مع التحقق من الملكية)
  // ═══════════════════════════════════════════════════════
  Future<bool> deleteCompetitor({
    required String id,
    required String userId,
  }) async {
    try {
      await _client
          .from('competitors')
          .delete()
          .eq('id', id)
          .eq('user_id', userId); // ✅ لا يمكن حذف منافس غيره
      return true;
    } catch (e) {
      print('❌ Error deleting competitor: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════
  // جلب إحصائيات المستخدم فقط
  // ═══════════════════════════════════════════════════════
  Future<Map<String, int>> getStats({required String userId}) async {
    try {
      final competitors = await _client
          .from('competitors')
          .select('id')
          .eq('user_id', userId); // ✅ فقط منافسيه

      int productsCount = 0;
      try {
        // جلب IDs منافسيه أولاً ثم احسب منتجاتهم
        final competitorIds =
            competitors.map((c) => c['id'] as String).toList();

        if (competitorIds.isNotEmpty) {
          final products = await _client
              .from('products')
              .select('id')
              .inFilter('competitor_id', competitorIds);
          productsCount = products.length;
        }
      } catch (e) {
        print('⚠️ Could not count products: $e');
        productsCount = 0;
      }

      int scannedThisWeek = 0;
      try {
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        final recentScans = await _client
            .from('competitors')
            .select('id')
            .eq('user_id', userId)
            .gte('created_at', weekAgo.toIso8601String());
        scannedThisWeek = recentScans.length;
      } catch (e) {
        print('⚠️ Could not get recent scans: $e');
        scannedThisWeek = 0;
      }

      return {
        'total': competitors.length,
        'products': productsCount,
        'scannedThisWeek': scannedThisWeek,
        'pendingScan': competitors.length - scannedThisWeek,
      };
    } catch (e) {
      print('❌ Error getting stats: $e');
      return {
        'total': 0,
        'products': 0,
        'scannedThisWeek': 0,
        'pendingScan': 0,
      };
    }
  }

  // ═══════════════════════════════════════════════════════
  // تشغيل scrape لمنافس (placeholder — سيُستكمل لاحقاً)
  // ═══════════════════════════════════════════════════════
  Future<bool> scanCompetitor({
    required String competitorId,
    required String userId,
  }) async {
    try {
      // تحديث وقت آخر scan
      await _client
          .from('competitors')
          .update({'last_scan_at': DateTime.now().toIso8601String()})
          .eq('id', competitorId)
          .eq('user_id', userId);

      // ⏳ هنا سيأتي منطق الـ scraping الحقيقي (Shopify, etc.)
      // حالياً فقط نحدّث وقت الـ scan
      print('🔍 Scan requested for competitor $competitorId');
      return true;
    } catch (e) {
      print('❌ Error scanning competitor: $e');
      return false;
    }
  }
}
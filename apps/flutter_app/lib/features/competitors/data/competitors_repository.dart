import 'package:supabase_flutter/supabase_flutter.dart';

/// Data class للمنافس
class Competitor {
  final String id;
  final String name;
  final String? website;
  final String? logoUrl;
  final String? shopifyStore;
  final DateTime createdAt;
  final DateTime? lastScanAt;
  final int productsCount;

  Competitor({
    required this.id,
    required this.name,
    this.website,
    this.logoUrl,
    this.shopifyStore,
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
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      lastScanAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
      productsCount: (map['products_count'] as int?) ?? 0,
    );
  }

  /// تنسيق "last scan" بالنسبي
  String get lastScanFormatted {
    if (lastScanAt == null) return 'Never scanned';
    
    final diff = DateTime.now().difference(lastScanAt!);
    
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
}

/// Repository لجلب وإدارة المنافسين
class CompetitorsRepository {
  final SupabaseClient _client;

  CompetitorsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// جلب كل المنافسين مع عدد منتجاتهم
  Future<List<Competitor>> getAll() async {
    try {
      final response = await _client
          .from('competitors')
          .select('*')
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

  /// ✅ إضافة منافس جديد (محدث لدعم RLS والعزل)
  Future<Competitor?> addCompetitor({
    required String name,
    String? website,
    String? shopifyStore,
    required String userId, // معامل جديد ضروري
  }) async {
    try {
      final response = await _client
          .from('competitors')
          .insert({
            'name': name,
            'website': website,
            'shopify_store': shopifyStore,
            'user_id': userId, // إرسال المعرف صراحة لضمان العزل
          })
          .select()
          .single();

      return Competitor.fromMap(response);
    } catch (e) {
      print('❌ Error adding competitor: $e');
      return null;
    }
  }

  /// حذف منافس
  Future<bool> deleteCompetitor(String id) async {
    try {
      await _client.from('competitors').delete().eq('id', id);
      return true;
    } catch (e) {
      print('❌ Error deleting competitor: $e');
      return false;
    }
  }

  /// جلب إحصائيات سريعة
  Future<Map<String, int>> getStats() async {
    try {
      final competitors = await _client.from('competitors').select('id');
      
      int productsCount = 0;
      try {
        final products = await _client.from('products').select('id');
        productsCount = products.length;
      } catch (e) {
        print('⚠️ Products table may not exist: $e');
        productsCount = 0;
      }
      
      int scannedThisWeek = 0;
      try {
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        final recentScans = await _client
            .from('competitors')
            .select('id')
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
}
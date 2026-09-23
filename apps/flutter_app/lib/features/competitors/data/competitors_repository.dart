import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ═══════════════════════════════════════════════════════
// 🎯 Custom Exceptions
// ═══════════════════════════════════════════════════════
class CompetitorException implements Exception {
  final String message;
  final String? code;
  final Object? cause;

  CompetitorException(this.message, {this.code, this.cause});

  @override
  String toString() => 'CompetitorException: $message${code != null ? ' ($code)' : ''}';
}

class ValidationException extends CompetitorException {
  ValidationException(super.message);
}

class NotFoundException extends CompetitorException {
  NotFoundException(String id) : super('Competitor not found', code: id);
}

// ═══════════════════════════════════════════════════════
// 🏪 Competitor Model — Enhanced & SAFE
// ═══════════════════════════════════════════════════════
@immutable
class Competitor {
  final String id;
  final String name;
  final String website; // ✅ تم جعله غير قابل للقيمة null لضمان عمل الـ Scraper
  final String? logoUrl;
  final String? shopifyStore;
  final String userId;
  final DateTime createdAt;
  final DateTime? lastScanAt;
  final int productsCount;

  const Competitor({
    required this.id,
    required this.name,
    required this.website,
    this.logoUrl,
    this.shopifyStore,
    required this.userId,
    required this.createdAt,
    this.lastScanAt,
    this.productsCount = 0,
  });

  factory Competitor.fromMap(Map<String, dynamic> map) {
    return Competitor(
      id: map['id']?.toString() ?? '',
      name: (map['name'] as String?)?.trim() ?? 'Unknown',
      website: (map['website'] as String?)?.trim() ?? 'https://unknown.com', // Fallback آمن
      logoUrl: map['logo_url'] as String?,
      shopifyStore: map['shopify_store'] as String?,
      userId: map['user_id']?.toString() ?? '',
      createdAt: _parseDateTime(map['created_at']) ?? DateTime.now(),
      lastScanAt: _parseDateTime(map['last_scan_at']),
      productsCount: (map['products_count'] != null) 
          ? int.tryParse(map['products_count'].toString()) ?? 0 
          : 0,
    );
  }

  Competitor copyWith({
    String? id,
    String? name,
    String? website,
    String? logoUrl,
    String? shopifyStore,
    String? userId,
    DateTime? createdAt,
    DateTime? lastScanAt,
    int? productsCount,
  }) {
    return Competitor(
      id: id ?? this.id,
      name: name ?? this.name,
      website: website ?? this.website,
      logoUrl: logoUrl ?? this.logoUrl,
      shopifyStore: shopifyStore ?? this.shopifyStore,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      lastScanAt: lastScanAt ?? this.lastScanAt,
      productsCount: productsCount ?? this.productsCount,
    );
  }

  String? get domain {
    try {
      final uri = Uri.parse(website.startsWith('http') ? website : 'https://${website}');
      return uri.host.replaceAll(RegExp(r'^www\.'), '');
    } catch (_) {
      return null;
    }
  }

  String? get faviconUrl {
    final d = domain;
    if (d == null) return null;
    return 'https://www.google.com/s2/favicons?domain=$d&sz=128';
  }

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';

  bool get isRecentlyScanned {
    if (lastScanAt == null) return false;
    return DateTime.now().difference(lastScanAt!).inDays < 7;
  }

  bool get needsUrgentScan {
    if (lastScanAt == null) return true;
    return DateTime.now().difference(lastScanAt!).inDays > 14;
  }

  String get lastScanFormatted {
    if (lastScanAt == null) return 'Never scanned';
    return _formatRelativeTime(lastScanAt!);
  }

  String get ageFormatted => _formatRelativeTime(createdAt);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Competitor && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Competitor(id: $id, name: $name, products: $productsCount)';

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }
}

// ═══════════════════════════════════════════════════════
// 🏛️ Competitors Repository — Bulletproof & Production Ready
// ═══════════════════════════════════════════════════════
class CompetitorsRepository {
  final SupabaseClient _client;
  final Duration _timeout;

  CompetitorsRepository({
    SupabaseClient? client,
    Duration timeout = const Duration(seconds: 30),
  })  : _client = client ?? Supabase.instance.client,
        _timeout = timeout;

  // ═══════════════════════════════════════════════════
  // 📋 READ OPERATIONS
  // ═══════════════════════════════════════════════════

  Future<List<Competitor>> getAll({required String userId}) async {
    _validateUserId(userId);
    try {
      final competitors = await _withTimeout(
        () => _client
            .from('competitors')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false),
        operation: 'getAll competitors',
      );

      if (competitors.isEmpty) return const [];

      final competitorIds = competitors.map((c) => c['id'] as String).toList();
      final productsCountMap = await _batchCountProducts(competitorIds);

      return competitors.map((map) {
        final id = map['id'] as String;
        return Competitor.fromMap({
          ...map,
          'products_count': productsCountMap[id] ?? 0,
        });
      }).toList();
    } catch (e, stack) {
      _logError('getAll', e, stack);
      return const [];
    }
  }

  Future<Competitor?> getById({required String id, required String userId}) async {
    _validateUserId(userId);
    try {
      final response = await _withTimeout(
        () => _client
            .from('competitors')
            .select()
            .eq('id', id)
            .eq('user_id', userId)
            .maybeSingle(),
        operation: 'getById',
      );

      if (response == null) return null;

      final count = await _countProductsForCompetitor(id);
      return Competitor.fromMap({...response, 'products_count': count});
    } catch (e, stack) {
      _logError('getById', e, stack);
      return null;
    }
  }

  Future<Competitor?> findByWebsite({required String website, required String userId}) async {
    _validateUserId(userId);
    if (website.trim().isEmpty) return null;

    try {
      final normalized = _normalizeUrl(website.trim());
      final response = await _withTimeout(
        () => _client
            .from('competitors')
            .select()
            .eq('user_id', userId)
            .eq('website', normalized)
            .maybeSingle(),
        operation: 'findByWebsite',
      );

      return response == null ? null : Competitor.fromMap(response);
    } catch (e, stack) {
      _logError('findByWebsite', e, stack);
      return null;
    }
  }

  // ═══════════════════════════════════════════════════
  // ✏️ WRITE OPERATIONS (مع تحقق صارم من Website)
  // ═══════════════════════════════════════════════════

  Future<Competitor> addCompetitor({
    required String name,
    required String userId,
    String? website,
    String? shopifyStore,
  }) async {
    _validateUserId(userId);

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ValidationException('Competitor name cannot be empty');
    }
    if (trimmedName.length > 100) {
      throw ValidationException('Name must be less than 100 characters');
    }

    // ✅ تحقق صارم: يجب وجود موقع إلكتروني لكي يعمل الـ Scraper
    String finalWebsite;
    if (website?.trim().isNotEmpty == true) {
      finalWebsite = _normalizeUrl(website!.trim());
    } else if (trimmedName.contains('.') && !trimmedName.contains(' ')) {
      // إذا أدخل المستخدم اسم النطاق مباشرة (مثل allbirds.com)
      finalWebsite = _normalizeUrl(trimmedName);
    } else {
      throw ValidationException('A valid website URL or domain is required to scan the competitor.');
    }

    final normalizedShopify = shopifyStore?.trim().isNotEmpty == true 
        ? _normalizeUrl(shopifyStore!.trim()) 
        : null;

    // منع التكرار
    final existing = await findByWebsite(website: finalWebsite, userId: userId);
    if (existing != null) {
      throw CompetitorException('A competitor with this website already exists', code: 'DUPLICATE_WEBSITE');
    }

    try {
      final response = await _withTimeout(
        () => _client
            .from('competitors')
            .insert({
              'name': trimmedName,
              'website': finalWebsite, // ✅ مضمون أنه ليس null
              'shopify_store': normalizedShopify,
              'user_id': userId,
            })
            .select()
            .single(),
        operation: 'addCompetitor',
      );

      _logInfo('addCompetitor', 'Added: $trimmedName (id: ${response['id']})');
      return Competitor.fromMap(response);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw CompetitorException('A competitor with this website already exists', code: 'DUPLICATE');
      }
      if (e.code == '23502') {
        throw CompetitorException('Website URL is required and cannot be null', code: 'NOT_NULL');
      }
      throw CompetitorException('Failed to add competitor: ${e.message}', code: e.code, cause: e);
    } catch (e, stack) {
      _logError('addCompetitor', e, stack);
      throw CompetitorException('Failed to add competitor', cause: e);
    }
  }

  Future<Competitor> updateCompetitor({
    required String id,
    required String userId,
    String? name,
    String? website,
    String? shopifyStore,
    DateTime? lastScanAt,
  }) async {
    _validateUserId(userId);

    final updateData = <String, dynamic>{};
    if (name != null && name.trim().isNotEmpty) updateData['name'] = name.trim();
    if (website != null) updateData['website'] = website.trim().isEmpty ? null : _normalizeUrl(website.trim());
    if (shopifyStore != null) updateData['shopify_store'] = shopifyStore.trim().isEmpty ? null : _normalizeUrl(shopifyStore.trim());
    if (lastScanAt != null) updateData['last_scan_at'] = lastScanAt.toIso8601String();

    if (updateData.isEmpty) throw ValidationException('No fields to update');

    try {
      final response = await _withTimeout(
        () => _client
            .from('competitors')
            .update(updateData)
            .eq('id', id)
            .eq('user_id', userId)
            .select()
            .single(),
        operation: 'updateCompetitor',
      );

      _logInfo('updateCompetitor', 'Updated: $id');
      return Competitor.fromMap(response);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') throw NotFoundException(id);
      throw CompetitorException('Failed to update: ${e.message}', code: e.code, cause: e);
    } catch (e, stack) {
      _logError('updateCompetitor', e, stack);
      throw CompetitorException('Failed to update competitor', cause: e);
    }
  }

  Future<bool> deleteCompetitor({required String id, required String userId}) async {
    _validateUserId(userId);
    try {
      final exists = await _client
          .from('competitors')
          .select('id')
          .eq('id', id)
          .eq('user_id', userId)
          .maybeSingle();

      if (exists == null) throw NotFoundException(id);

      await _withTimeout(
        () => _client.from('competitors').delete().eq('id', id).eq('user_id', userId),
        operation: 'deleteCompetitor',
      );

      _logInfo('deleteCompetitor', 'Deleted: $id');
      return true;
    } catch (e, stack) {
      _logError('deleteCompetitor', e, stack);
      throw CompetitorException('Failed to delete competitor', cause: e);
    }
  }

  Future<int> deleteMany({
    required List<String> ids,
    required String userId,
  }) async {
    _validateUserId(userId);
    if (ids.isEmpty) return 0;

    try {
      final response = await _withTimeout(
        () => _client
            .from('competitors')
            .delete()
            .inFilter('id', ids)
            .eq('user_id', userId)
            .select('id'),
        operation: 'deleteMany',
      );

      _logInfo('deleteMany', 'Deleted ${response.length} competitors');
      return response.length;
    } catch (e, stack) {
      _logError('deleteMany', e, stack);
      throw CompetitorException('Failed to delete competitors', cause: e);
    }
  }

  // ═══════════════════════════════════════════════════
  // 📊 ANALYTICS & STATS
  // ═══════════════════════════════════════════════════

  Future<CompetitorStats> getStats({required String userId}) async {
    _validateUserId(userId);
    try {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));

      final competitors = await _client
          .from('competitors')
          .select('id, last_scan_at')
          .eq('user_id', userId);

      final products = await _getTotalProductsCount(userId);

      final total = competitors.length;
      var scannedThisWeek = 0;
      var neverScanned = 0;
      
      for (final row in competitors) {
        final lastScan = Competitor._parseDateTime(row['last_scan_at']);
        if (lastScan == null) {
          neverScanned++;
        } else if (lastScan.isAfter(weekAgo)) {
          scannedThisWeek++;
        }
      }

      return CompetitorStats(
        total: total,
        products: products,
        scannedThisWeek: scannedThisWeek,
        pendingScan: total - scannedThisWeek,
        neverScanned: neverScanned,
      );
    } catch (e, stack) {
      _logError('getStats', e, stack);
      return CompetitorStats.empty;
    }
  }

  // ═══════════════════════════════════════════════════
  // 🔧 PRIVATE HELPERS
  // ═══════════════════════════════════════════════════

  Future<Map<String, int>> _batchCountProducts(List<String> competitorIds) async {
    if (competitorIds.isEmpty) return {};
    try {
      final products = await _client
          .from('products')
          .select('competitor_id')
          .inFilter('competitor_id', competitorIds);

      final counts = <String, int>{};
      for (final p in products) {
        final cid = p['competitor_id'] as String;
        counts[cid] = (counts[cid] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      _logError('_batchCountProducts', e, null);
      return {};
    }
  }

  Future<int> _countProductsForCompetitor(String competitorId) async {
    try {
      final response = await _client
          .from('products')
          .select('id')
          .eq('competitor_id', competitorId);
      return response.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getTotalProductsCount(String userId) async {
    try {
      final competitors = await _client
          .from('competitors')
          .select('id')
          .eq('user_id', userId);

      final ids = competitors.map((c) => c['id'] as String).toList();
      if (ids.isEmpty) return 0;

      final response = await _client
          .from('products')
          .select('id')
          .inFilter('competitor_id', ids);

      return response.length;
    } catch (e) {
      return 0;
    }
  }

  String _normalizeUrl(String url) {
    if (url.isEmpty) return url;
    String normalized = url.trim();
    if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }
    // إزالة الشرطة المائلة الزائدة لمنع التكرار
    if (normalized.endsWith('/') && normalized.length > 9) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  void _validateUserId(String userId) {
    if (userId.isEmpty) {
      throw ValidationException('User ID is required');
    }
  }

  Future<T> _withTimeout<T>(Future<T> Function() action, {required String operation}) async {
    try {
      return await action().timeout(_timeout);
    } on TimeoutException {
      throw CompetitorException('Operation timed out after ${_timeout.inSeconds}s', code: 'TIMEOUT');
    }
  }

  void _logInfo(String operation, String message) {
    if (kDebugMode) debugPrint('✅ [$operation] $message');
  }

  void _logError(String operation, Object error, StackTrace? stack) {
    if (kDebugMode) {
      debugPrint('❌ [$operation] $error');
      if (stack != null && error is! CompetitorException) {
        debugPrint('Stack: ${stack.toString().split('\n').take(3).join('\n')}');
      }
    }
  }
}

// ═══════════════════════════════════════════════════════
// 📊 Stats Data Class
// ═══════════════════════════════════════════════════════
@immutable
class CompetitorStats {
  final int total;
  final int products;
  final int scannedThisWeek;
  final int pendingScan;
  final int neverScanned;

  const CompetitorStats({
    required this.total,
    required this.products,
    required this.scannedThisWeek,
    required this.pendingScan,
    this.neverScanned = 0,
  });

  static const empty = CompetitorStats(
    total: 0, products: 0, scannedThisWeek: 0, pendingScan: 0, neverScanned: 0,
  );

  double get scanRate => total == 0 ? 0 : scannedThisWeek / total;
  double get avgProductsPerCompetitor => total == 0 ? 0 : products / total;

  @override
  String toString() => 'CompetitorStats(total: $total, products: $products, scanned: $scannedThisWeek, pending: $pendingScan)';
}
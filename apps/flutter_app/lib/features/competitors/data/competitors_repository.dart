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

class PermissionException extends CompetitorException {
  PermissionException() : super('You do not have permission to perform this action');
}

// ═══════════════════════════════════════════════════════
// 🏪 Competitor Model — Enhanced
// ═══════════════════════════════════════════════════════
@immutable
class Competitor {
  final String id;
  final String name;
  final String? website;
  final String? logoUrl;
  final String? shopifyStore;
  final String userId;
  final DateTime createdAt;
  final DateTime? lastScanAt;
  final int productsCount;

  const Competitor({
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

  // ─── Factory Constructors ─────────────────────────
  factory Competitor.fromMap(Map<String, dynamic> map) {
    return Competitor(
      id: map['id']?.toString() ?? '',
      name: (map['name'] as String?)?.trim() ?? 'Unknown',
      website: map['website'] as String?,
      logoUrl: map['logo_url'] as String?,
      shopifyStore: map['shopify_store'] as String?,
      userId: map['user_id']?.toString() ?? '',
      createdAt: _parseDateTime(map['created_at']) ?? DateTime.now(),
      lastScanAt: _parseDateTime(map['last_scan_at']),
      productsCount: (map['products_count'] as num?)?.toInt() ?? 0,
    );
  }

  // ─── Copy With ────────────────────────────────────
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

  // ─── Computed Properties ──────────────────────────
  /// اسم النطاق (domain) المستخرج من website
  String? get domain {
    if (website == null || website!.isEmpty) return null;
    try {
      final uri = Uri.parse(website!.startsWith('http') ? website! : 'https://${website!}');
      return uri.host.replaceAll(RegExp(r'^www\.'), '');
    } catch (_) {
      return null;
    }
  }

  /// الشعار (favicon) من Google API
  String? get faviconUrl {
    final d = domain;
    if (d == null) return null;
    return 'https://www.google.com/s2/favicons?domain=$d&sz=128';
  }

  /// الحرف الأول (لـ fallback avatar)
  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';

  /// هل تم فحصه في آخر 7 أيام؟
  bool get isRecentlyScanned {
    if (lastScanAt == null) return false;
    return DateTime.now().difference(lastScanAt!).inDays < 7;
  }

  /// هل يحتاج فحص عاجل؟ (> 14 يوم أو لم يُفحص أبداً)
  bool get needsUrgentScan {
    if (lastScanAt == null) return true;
    return DateTime.now().difference(lastScanAt!).inDays > 14;
  }

  /// تنسيق "last scan" نسبي
  String get lastScanFormatted {
    if (lastScanAt == null) return 'Never scanned';
    return _formatRelativeTime(lastScanAt!);
  }

  /// العمر منذ الإنشاء
  String get ageFormatted => _formatRelativeTime(createdAt);

  // ─── Equality ─────────────────────────────────────
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Competitor &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Competitor(id: $id, name: $name, products: $productsCount)';

  // ─── Helpers ──────────────────────────────────────
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
// 🏛️ Competitors Repository — Expert Level
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

  /// جلب جميع المنافسين للمستخدم (مع عدد المنتجات — query واحد!)
  /// ✅ Optimized: Uses batch product counting (no N+1)
  Future<List<Competitor>> getAll({required String userId}) async {
    _validateUserId(userId);

    try {
      // 1. Fetch all competitors
      final competitors = await _withTimeout(
        () => _client
            .from('competitors')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false),
        operation: 'getAll competitors',
      );

      if (competitors.isEmpty) return const [];

      // 2. Batch count products for all competitors (single query)
      final competitorIds = competitors.map((c) => c['id'] as String).toList();
      final productsCountMap = await _batchCountProducts(competitorIds);

      // 3. Merge counts into competitors
      return competitors.map((map) {
        final id = map['id'] as String;
        return Competitor.fromMap({
          ...map,
          'products_count': productsCountMap[id] ?? 0,
        });
      }).toList();
    } on CompetitorException {
      rethrow;
    } catch (e, stack) {
      _logError('getAll', e, stack);
      return const [];
    }
  }

  /// جلب منافس واحد بالـ ID
  Future<Competitor?> getById({
    required String id,
    required String userId,
  }) async {
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

      // Count products
      final count = await _countProductsForCompetitor(id);
      return Competitor.fromMap({...response, 'products_count': count});
    } on CompetitorException {
      rethrow;
    } catch (e, stack) {
      _logError('getById', e, stack);
      return null;
    }
  }

  /// التحقق من وجود منافس بالـ website
  Future<Competitor?> findByWebsite({
    required String website,
    required String userId,
  }) async {
    _validateUserId(userId);
    if (website.isEmpty) return null;

    try {
      final response = await _withTimeout(
        () => _client
            .from('competitors')
            .select()
            .eq('user_id', userId)
            .eq('website', website)
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
  // ✏️ WRITE OPERATIONS
  // ═══════════════════════════════════════════════════

  /// إضافة منافس جديد (مع validation + duplicate check)
  Future<Competitor> addCompetitor({
    required String name,
    required String userId,
    String? website,
    String? shopifyStore,
  }) async {
    _validateUserId(userId);

    // Validation
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ValidationException('Competitor name cannot be empty');
    }
    if (trimmedName.length > 100) {
      throw ValidationException('Name must be less than 100 characters');
    }

    final normalizedWebsite = website?.trim().isNotEmpty == true
        ? _normalizeUrl(website!.trim())
        : null;
    final normalizedShopify = shopifyStore?.trim().isNotEmpty == true
        ? _normalizeUrl(shopifyStore!.trim())
        : null;

    // Duplicate check
    if (normalizedWebsite != null) {
      final existing = await findByWebsite(
        website: normalizedWebsite,
        userId: userId,
      );
      if (existing != null) {
        throw CompetitorException(
          'A competitor with this website already exists',
          code: 'DUPLICATE_WEBSITE',
        );
      }
    }

    try {
      final response = await _withTimeout(
        () => _client
            .from('competitors')
            .insert({
              'name': trimmedName,
              'website': normalizedWebsite,
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
        throw CompetitorException('A competitor with this data already exists', code: 'DUPLICATE');
      }
      throw CompetitorException('Failed to add competitor: ${e.message}', code: e.code, cause: e);
    } catch (e, stack) {
      _logError('addCompetitor', e, stack);
      throw CompetitorException('Failed to add competitor', cause: e);
    }
  }

  /// تحديث منافس (مع التحقق من الملكية)
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
    if (name != null && name.trim().isNotEmpty) {
      updateData['name'] = name.trim();
    }
    if (website != null) {
      updateData['website'] = website.trim().isEmpty ? null : _normalizeUrl(website.trim());
    }
    if (shopifyStore != null) {
      updateData['shopify_store'] = shopifyStore.trim().isEmpty ? null : _normalizeUrl(shopifyStore.trim());
    }
    if (lastScanAt != null) {
      updateData['last_scan_at'] = lastScanAt.toIso8601String();
    }

    if (updateData.isEmpty) {
      throw ValidationException('No fields to update');
    }

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
      if (e.code == 'PGRST116') {
        throw NotFoundException(id);
      }
      throw CompetitorException('Failed to update: ${e.message}', code: e.code, cause: e);
    } catch (e, stack) {
      _logError('updateCompetitor', e, stack);
      throw CompetitorException('Failed to update competitor', cause: e);
    }
  }

  /// حذف منافس واحد (مع cascade للمنتجات والرؤى)
  Future<bool> deleteCompetitor({
    required String id,
    required String userId,
  }) async {
    _validateUserId(userId);

    try {
      // Verify ownership first
      final exists = await _client
          .from('competitors')
          .select('id')
          .eq('id', id)
          .eq('user_id', userId)
          .maybeSingle();

      if (exists == null) {
        throw NotFoundException(id);
      }

      await _withTimeout(
        () => _client.from('competitors').delete().eq('id', id).eq('user_id', userId),
        operation: 'deleteCompetitor',
      );

      _logInfo('deleteCompetitor', 'Deleted: $id');
      return true;
    } on CompetitorException {
      rethrow;
    } catch (e, stack) {
      _logError('deleteCompetitor', e, stack);
      throw CompetitorException('Failed to delete competitor', cause: e);
    }
  }

  /// حذف عدة منافسين دفعة واحدة (batch delete)
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

  /// إحصائيات المستخدم (محسّنة — queries أقل)
  Future<CompetitorStats> getStats({required String userId}) async {
    _validateUserId(userId);

    try {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));

      final competitorsFuture = _client
          .from('competitors')
          .select('id, last_scan_at')
          .eq('user_id', userId);
      final productsFuture = _getTotalProductsCount(userId);

      final competitors = await competitorsFuture;
      final products = await productsFuture;

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

  /// تسجيل بدء عملية scan (يُستدعى قبل تشغيل scraper)
  Future<bool> markScanStarted({
    required String competitorId,
    required String userId,
  }) async {
    try {
      await updateCompetitor(
        id: competitorId,
        userId: userId,
        lastScanAt: DateTime.now(),
      );
      return true;
    } catch (e) {
      _logError('markScanStarted', e, null);
      return false;
    }
  }

  // ═══════════════════════════════════════════════════
  // 🔧 PRIVATE HELPERS
  // ═══════════════════════════════════════════════════

  /// Batch count products for multiple competitors (single query approach)
  Future<Map<String, int>> _batchCountProducts(List<String> competitorIds) async {
    if (competitorIds.isEmpty) return {};

    try {
      final products = await _client
          .from('products')
          .select('competitor_id')
          .inFilter('competitor_id', competitorIds);

      // Group by competitor_id
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
      // Get all competitor IDs
      final competitors = await _client
          .from('competitors')
          .select('id')
          .eq('user_id', userId);

      final ids = competitors.map((c) => c['id'] as String).toList();
      if (ids.isEmpty) return 0;

      final products = await _client
          .from('products')
          .select('id')
          .inFilter('competitor_id', ids);

      return products.length;
    } catch (e) {
      return 0;
    }
  }

  /// Normalize URL (add https:// if missing)
  String _normalizeUrl(String url) {
    if (url.isEmpty) return url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return 'https://$url';
    }
    return url;
  }

  void _validateUserId(String userId) {
    if (userId.isEmpty) {
      throw ValidationException('User ID is required');
    }
  }

  /// Execute operation with timeout
  Future<T> _withTimeout<T>(
    Future<T> Function() action, {
    required String operation,
  }) async {
    try {
      return await action().timeout(_timeout);
    } on TimeoutException {
      throw CompetitorException(
        'Operation timed out after ${_timeout.inSeconds}s',
        code: 'TIMEOUT',
      );
    }
  }

  // ─── Logging Helpers ─────────────────────────────
  void _logInfo(String operation, String message) {
    if (kDebugMode) {
      debugPrint('✅ [$operation] $message');
    }
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
    total: 0,
    products: 0,
    scannedThisWeek: 0,
    pendingScan: 0,
    neverScanned: 0,
  );

  /// نسبة المنافسين المفحوصين هذا الأسبوع
  double get scanRate => total == 0 ? 0 : scannedThisWeek / total;

  /// متوسط المنتجات لكل منافس
  double get avgProductsPerCompetitor =>
      total == 0 ? 0 : products / total;

  Map<String, int> toMap() => {
        'total': total,
        'products': products,
        'scannedThisWeek': scannedThisWeek,
        'pendingScan': pendingScan,
        'neverScanned': neverScanned,
      };

  @override
  String toString() => 'CompetitorStats(total: $total, products: $products, '
      'scanned: $scannedThisWeek, pending: $pendingScan)';
}
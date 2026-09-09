import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/competitors_repository.dart';

// ═══════════════════════════════════════════
// 🏛️ Repository Provider
// ═══════════════════════════════════════════

/// Provider للـ Repository (Singleton)
final competitorsRepositoryProvider = Provider<CompetitorsRepository>((ref) {
  return CompetitorsRepository();
});

// ═══════════════════════════════════════════
// 🔐 Auth Helper
// ═══════════════════════════════════════════

/// جلب ID المستخدم الحالي من Supabase Auth
String? _getCurrentUserId() {
  return Supabase.instance.client.auth.currentUser?.id;
}

// ═══════════════════════════════════════════
// 📊 Data Providers
// ═══════════════════════════════════════════

/// Provider لجلب كل المنافسين (معزل بالمستخدم)
final competitorsListProvider = FutureProvider<List<Competitor>>((ref) async {
  final userId = _getCurrentUserId();
  if (userId == null) {
    _logWarning('competitorsListProvider', 'No user logged in');
    return const [];
  }

  final repository = ref.watch(competitorsRepositoryProvider);
  return repository.getAll(userId: userId);
});

/// Provider لإحصائيات المنافسين (معزل بالمستخدم)
/// ✅ Updated: Returns CompetitorStats instead of Map<String, int>
final competitorsStatsProvider = FutureProvider<CompetitorStats>((ref) async {
  final userId = _getCurrentUserId();
  if (userId == null) {
    _logWarning('competitorsStatsProvider', 'No user logged in');
    return CompetitorStats.empty;
  }

  final repository = ref.watch(competitorsRepositoryProvider);
  return repository.getStats(userId: userId);
});

// ═══════════════════════════════════════════
// 🔍 UI State Providers
// ═══════════════════════════════════════════

/// Provider للبحث (Search Query)
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Provider للمنافسين المفلترين (حسب البحث)
final filteredCompetitorsProvider = Provider<List<Competitor>>((ref) {
  final competitorsAsync = ref.watch(competitorsListProvider);
  final searchQuery = ref.watch(searchQueryProvider).toLowerCase();

  return competitorsAsync.whenOrNull(
        data: (competitors) {
          if (searchQuery.isEmpty) return competitors;
          return competitors.where((c) {
            final name = c.name.toLowerCase();
            final website = (c.website ?? '').toLowerCase();
            final domain = (c.domain ?? '').toLowerCase();
            return name.contains(searchQuery) || 
                   website.contains(searchQuery) || 
                   domain.contains(searchQuery);
          }).toList();
        },
      ) ??
      const [];
});

// ═══════════════════════════════════════════
// ⚡ Action Providers
// ═══════════════════════════════════════════

/// Provider لإضافة منافس جديد
final addCompetitorProvider =
    FutureProvider.autoDispose.family<bool, AddCompetitorParams>(
  (ref, params) async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      _logError('addCompetitorProvider', 'No user logged in');
      return false;
    }

    final repository = ref.read(competitorsRepositoryProvider);

    try {
      await repository.addCompetitor(
        userId: userId,
        name: params.name,
        website: params.website,
        shopifyStore: params.shopifyStore,
      );

      ref.invalidate(competitorsListProvider);
      ref.invalidate(competitorsStatsProvider);
      _logInfo('addCompetitorProvider', 'Added: ${params.name}');
      return true;
    } on CompetitorException catch (e) {
      _logError('addCompetitorProvider', e);
      rethrow; // Re-throw so UI can show proper error
    } catch (e) {
      _logError('addCompetitorProvider', e);
      return false;
    }
  },
);

/// Provider لحذف منافس
final deleteCompetitorProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, id) async {
  final userId = _getCurrentUserId();
  if (userId == null) {
    _logError('deleteCompetitorProvider', 'No user logged in');
    return false;
  }

  final repository = ref.read(competitorsRepositoryProvider);

  try {
    final result = await repository.deleteCompetitor(
      id: id,
      userId: userId,
    );

    if (result) {
      // Refresh lists after successful delete
      ref.invalidate(competitorsListProvider);
      ref.invalidate(competitorsStatsProvider);
      _logInfo('deleteCompetitorProvider', 'Deleted: $id');
    }
    return result;
  } on CompetitorException catch (e) {
    _logError('deleteCompetitorProvider', e);
    return false;
  } catch (e) {
    _logError('deleteCompetitorProvider', e);
    return false;
  }
});

/// Provider لتحديث منافس (مثل last_scan_at)
final updateCompetitorProvider =
    FutureProvider.autoDispose.family<bool, UpdateCompetitorParams>(
  (ref, params) async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      _logError('updateCompetitorProvider', 'No user logged in');
      return false;
    }

    final repository = ref.read(competitorsRepositoryProvider);

    try {
      await repository.updateCompetitor(
        id: params.id,
        userId: userId,
        name: params.name,
        website: params.website,
        shopifyStore: params.shopifyStore,
        lastScanAt: params.lastScanAt,
      );

      ref.invalidate(competitorsListProvider);
      ref.invalidate(competitorsStatsProvider);
      return true;
    } on CompetitorException catch (e) {
      _logError('updateCompetitorProvider', e);
      return false;
    }
  },
);

/// Provider لحذف عدة منافسين (batch)
final deleteManyCompetitorsProvider =
    FutureProvider.autoDispose.family<int, List<String>>((ref, ids) async {
  final userId = _getCurrentUserId();
  if (userId == null) return 0;

  final repository = ref.read(competitorsRepositoryProvider);

  try {
    final count = await repository.deleteMany(ids: ids, userId: userId);
    if (count > 0) {
      ref.invalidate(competitorsListProvider);
      ref.invalidate(competitorsStatsProvider);
    }
    return count;
  } catch (e) {
    _logError('deleteManyCompetitorsProvider', e);
    return 0;
  }
});

/// Provider للـ pull-to-refresh
final refreshCompetitorsProvider = Provider((ref) {
  return () {
    ref.invalidate(competitorsListProvider);
    ref.invalidate(competitorsStatsProvider);
    _logInfo('refreshCompetitorsProvider', 'Refreshed');
  };
});

// ═══════════════════════════════════════════
// 📦 Data Classes
// ═══════════════════════════════════════════

/// معطيات إضافة منافس جديد
class AddCompetitorParams {
  final String name;
  final String? website;
  final String? shopifyStore;

  const AddCompetitorParams({
    required this.name,
    this.website,
    this.shopifyStore,
  });
}

/// معطيات تحديث منافس
class UpdateCompetitorParams {
  final String id;
  final String? name;
  final String? website;
  final String? shopifyStore;
  final DateTime? lastScanAt;

  const UpdateCompetitorParams({
    required this.id,
    this.name,
    this.website,
    this.shopifyStore,
    this.lastScanAt,
  });
}

// ═══════════════════════════════════════════
// 📝 Logging Helpers (Production-safe)
// ═══════════════════════════════════════════

void _logInfo(String provider, String message) {
  if (kDebugMode) {
    debugPrint('✅ [$provider] $message');
  }
}

void _logWarning(String provider, String message) {
  if (kDebugMode) {
    debugPrint('⚠️ [$provider] $message');
  }
}

void _logError(String provider, Object error) {
  if (kDebugMode) {
    debugPrint('❌ [$provider] $error');
  }
}
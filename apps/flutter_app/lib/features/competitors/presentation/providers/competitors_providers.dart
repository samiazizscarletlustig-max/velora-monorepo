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

/// جلب ID المستخدم الحالي من Supabase Auth بشكل آمن
String? _getCurrentUserId() {
  final user = Supabase.instance.client.auth.currentUser;
  final userId = user?.id;
  
  // ✅ FIX: Ensure userId is not null AND not empty
  if (userId == null || userId.trim().isEmpty) {
    return null;
  }
  return userId.trim();
}

// ═══════════════════════════════════════════
// 📊 Data Providers
// ═══════════════════════════════════════════

/// Provider لجلب كل المنافسين (معزل بالمستخدم)
final competitorsListProvider = FutureProvider<List<Competitor>>((ref) async {
  final userId = _getCurrentUserId();
  if (userId == null) {
    _logWarning('competitorsListProvider', 'No user logged in or userId is empty. Returning empty list.');
    return const [];
  }

  _logInfo('competitorsListProvider', 'Fetching competitors for userId: $userId');
  final repository = ref.watch(competitorsRepositoryProvider);
  
  try {
    return await repository.getAll(userId: userId);
  } catch (e, stack) {
    _logError('competitorsListProvider', 'Failed to fetch: $e', stack);
    rethrow; // Let the UI handle the error state
  }
});

/// Provider لإحصائيات المنافسين (معزل بالمستخدم)
final competitorsStatsProvider = FutureProvider<CompetitorStats>((ref) async {
  final userId = _getCurrentUserId();
  if (userId == null) {
    _logWarning('competitorsStatsProvider', 'No user logged in. Returning empty stats.');
    return CompetitorStats.empty;
  }

  final repository = ref.watch(competitorsRepositoryProvider);
  
  try {
    return await repository.getStats(userId: userId);
  } catch (e, stack) {
    _logError('competitorsStatsProvider', 'Failed to fetch stats: $e', stack);
    return CompetitorStats.empty; // Fallback to empty stats on error to prevent UI crash
  }
});

// ═══════════════════════════════════════════
// 🔍 UI State Providers
// ═══════════════════════════════════════════

/// Provider للبحث (Search Query)
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Provider للمنافسين المفلترين (حسب البحث)
final filteredCompetitorsProvider = Provider<List<Competitor>>((ref) {
  final competitorsAsync = ref.watch(competitorsListProvider);
  final searchQuery = ref.watch(searchQueryProvider).toLowerCase().trim();

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
      ) ?? const [];
});

// ═══════════════════════════════════════════
// ⚡ Action Providers
// ═══════════════════════════════════════════

/// Provider لإضافة منافس جديد
final addCompetitorProvider = FutureProvider.autoDispose.family<bool, AddCompetitorParams>(
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

      // ✅ FIX: Invalidate to refresh UI immediately
      ref.invalidate(competitorsListProvider);
      ref.invalidate(competitorsStatsProvider);
      
      _logInfo('addCompetitorProvider', 'Successfully added: ${params.name}');
      return true;
    } on CompetitorException catch (e) {
      _logError('addCompetitorProvider', 'CompetitorException: ${e.message}');
      rethrow; // Re-throw so UI dialog can show the specific error message
    } catch (e, stack) {
      _logError('addCompetitorProvider', 'Unexpected error: $e', stack);
      return false;
    }
  },
);

/// Provider لحذف منافس
final deleteCompetitorProvider = FutureProvider.autoDispose.family<bool, String>((ref, id) async {
  final userId = _getCurrentUserId();
  if (userId == null) {
    _logError('deleteCompetitorProvider', 'No user logged in');
    return false;
  }

  final repository = ref.read(competitorsRepositoryProvider);

  try {
    final result = await repository.deleteCompetitor(id: id, userId: userId);

    if (result) {
      ref.invalidate(competitorsListProvider);
      ref.invalidate(competitorsStatsProvider);
      _logInfo('deleteCompetitorProvider', 'Successfully deleted: $id');
    }
    return result;
  } on CompetitorException catch (e) {
    _logError('deleteCompetitorProvider', 'CompetitorException: ${e.message}');
    return false;
  } catch (e, stack) {
    _logError('deleteCompetitorProvider', 'Unexpected error: $e', stack);
    return false;
  }
});

/// Provider لتحديث منافس (مثل last_scan_at)
final updateCompetitorProvider = FutureProvider.autoDispose.family<bool, UpdateCompetitorParams>(
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
      _logInfo('updateCompetitorProvider', 'Successfully updated: ${params.id}');
      return true;
    } on CompetitorException catch (e) {
      _logError('updateCompetitorProvider', 'CompetitorException: ${e.message}');
      return false;
    } catch (e, stack) {
      _logError('updateCompetitorProvider', 'Unexpected error: $e', stack);
      return false;
    }
  },
);

/// Provider لحذف عدة منافسين (batch)
final deleteManyCompetitorsProvider = FutureProvider.autoDispose.family<int, List<String>>((ref, ids) async {
  final userId = _getCurrentUserId();
  if (userId == null) {
    _logError('deleteManyCompetitorsProvider', 'No user logged in');
    return 0;
  }

  final repository = ref.read(competitorsRepositoryProvider);

  try {
    final count = await repository.deleteMany(ids: ids, userId: userId);
    if (count > 0) {
      ref.invalidate(competitorsListProvider);
      ref.invalidate(competitorsStatsProvider);
      _logInfo('deleteManyCompetitorsProvider', 'Successfully deleted $count competitors');
    }
    return count;
  } catch (e, stack) {
    _logError('deleteManyCompetitorsProvider', 'Unexpected error: $e', stack);
    return 0;
  }
});

/// Provider للـ pull-to-refresh
final refreshCompetitorsProvider = Provider((ref) {
  return () {
    _logInfo('refreshCompetitorsProvider', 'Manual refresh triggered');
    ref.invalidate(competitorsListProvider);
    ref.invalidate(competitorsStatsProvider);
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

void _logError(String provider, Object error, [StackTrace? stack]) {
  if (kDebugMode) {
    debugPrint('❌ [$provider] $error');
    if (stack != null) {
      debugPrint('Stack trace: ${stack.toString().split('\n').take(4).join('\n')}');
    }
  }
}
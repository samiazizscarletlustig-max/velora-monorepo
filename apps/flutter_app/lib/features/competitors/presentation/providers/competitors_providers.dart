import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/competitors_repository.dart';

// ═══════════════════════════════════════════
// Repository Provider
// ═══════════════════════════════════════════

/// Provider للـ Repository (Singleton)
final competitorsRepositoryProvider = Provider<CompetitorsRepository>((ref) {
  return CompetitorsRepository();
});

// ═══════════════════════════════════════════
// Auth Helper
// ═══════════════════════════════════════════

/// جلب ID المستخدم الحالي من Supabase Auth
String? _getCurrentUserId() {
  return Supabase.instance.client.auth.currentUser?.id;
}

// ═══════════════════════════════════════════
// Data Providers
// ═══════════════════════════════════════════

/// Provider لجلب كل المنافسين (معزل بالمستخدم)
final competitorsListProvider = FutureProvider<List<Competitor>>((ref) async {
  final userId = _getCurrentUserId();
  if (userId == null) {
    // المستخدم غير مسجل دخول — أعد قائمة فارغة
    return [];
  }

  final repository = ref.watch(competitorsRepositoryProvider);
  return repository.getAll(userId: userId);
});

/// Provider لإحصائيات المنافسين (معزل بالمستخدم)
final competitorsStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final userId = _getCurrentUserId();
  if (userId == null) {
    // المستخدم غير مسجل دخول — أعد إحصائيات صفرية
    return {
      'total': 0,
      'products': 0,
      'scannedThisWeek': 0,
      'pendingScan': 0,
    };
  }

  final repository = ref.watch(competitorsRepositoryProvider);
  return repository.getStats(userId: userId);
});

// ═══════════════════════════════════════════
// UI State Providers
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
            return name.contains(searchQuery) || website.contains(searchQuery);
          }).toList();
        },
      ) ??
      [];
});

// ═══════════════════════════════════════════
// Action Providers (AsyncValue)
// ═══════════════════════════════════════════

/// Provider لإضافة منافس جديد
final addCompetitorProvider =
    FutureProvider.autoDispose.family<bool, AddCompetitorParams>(
  (ref, params) async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      print('❌ Cannot add competitor: no user logged in');
      return false;
    }

    final repository = ref.read(competitorsRepositoryProvider);

    final result = await repository.addCompetitor(
      userId: userId,
      name: params.name,
      website: params.website,
      shopifyStore: params.shopifyStore,
    );

    if (result != null) {
      // تحديث القوائم بعد الإضافة
      ref.invalidate(competitorsListProvider);
      ref.invalidate(competitorsStatsProvider);
      return true;
    }
    return false;
  },
);

/// Provider لحذف منافس
final deleteCompetitorProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, id) async {
  final userId = _getCurrentUserId();
  if (userId == null) {
    print('❌ Cannot delete competitor: no user logged in');
    return false;
  }

  final repository = ref.read(competitorsRepositoryProvider);
  final result = await repository.deleteCompetitor(
    id: id,
    userId: userId,
  );

  if (result) {
    // تحديث القوائم بعد الحذف
    ref.invalidate(competitorsListProvider);
    ref.invalidate(competitorsStatsProvider);
  }
  return result;
});

// ═══════════════════════════════════════════
// Data Classes
// ═══════════════════════════════════════════

/// معطيات إضافة منافس جديد
class AddCompetitorParams {
  final String name;
  final String? website;
  final String? shopifyStore;

  AddCompetitorParams({
    required this.name,
    this.website,
    this.shopifyStore,
  });
}
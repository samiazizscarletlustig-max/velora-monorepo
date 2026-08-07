import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/competitors_repository.dart';

// ═══════════════════════════════════════════
// Repository Provider
// ══════════════════════════════════════════

/// Provider للـ Repository (Singleton)
final competitorsRepositoryProvider = Provider<CompetitorsRepository>((ref) {
  return CompetitorsRepository();
});

// ══════════════════════════════════════════
// Data Providers
// ═══════════════════════════════════════════

/// Provider لجلب كل المنافسين
final competitorsListProvider = FutureProvider<List<Competitor>>((ref) async {
  final repository = ref.watch(competitorsRepositoryProvider);
  return repository.getAll();
});

/// Provider لإحصائيات المنافسين
final competitorsStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repository = ref.watch(competitorsRepositoryProvider);
  return repository.getStats();
});

// ══════════════════════════════════════════
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
    final repository = ref.read(competitorsRepositoryProvider);
    
    // ✅ تم وضع الـ UID الخاص بك للتجربة على الويب
    // ⚠️ TODO: قبل النشر، استبدل هذا السطر بجلب الـ ID ديناميكياً من Supabase Auth
    final userId = "20a37844-b75d-4064-bf86-3bbe3c59e22d"; 

    final result = await repository.addCompetitor(
      userId: userId,
      name: params.name,
      website: params.website,
      shopifyStore: params.shopifyStore,
    );

    if (result != null) {
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
  final repository = ref.read(competitorsRepositoryProvider);
  final result = await repository.deleteCompetitor(id);

  if (result) {
    ref.invalidate(competitorsListProvider);
    ref.invalidate(competitorsStatsProvider);
  }
  return result;
});

// ═══════════════════════════════════════════
// Data Classes
// ══════════════════════════════════════════

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
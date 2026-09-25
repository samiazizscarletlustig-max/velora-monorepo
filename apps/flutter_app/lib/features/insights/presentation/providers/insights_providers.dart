import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/insights_repository.dart''''').toLowerCase();
              return title.contains(searchQuery) || 
                     summary.contains(searchQuery) ||
                     competitor.contains(searchQuery);
            }).toList();
          }
          
          return filtered;
        },
      ) ??
      [];
});

// ═══════════════════════════════════════════
// Action Providers
// ═══════════════════════════════════════════

/// Provider لDelete Insight
final deleteInsightProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, id) async {
  final repository = ref.read(insightsRepositoryProvider);
  final result = await repository.deleteInsight(id);

  if (result) {
    // Refresh the list after successful deletion
    ref.invalidate(insightsListProvider);
    ref.invalidate(insightsStatsProvider);
  }
  return result;
});
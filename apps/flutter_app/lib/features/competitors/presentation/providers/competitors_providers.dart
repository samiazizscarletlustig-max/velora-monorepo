import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/competitors_repository.dart''competitorsListProvider', 'No user logged in or userId is empty. Returning empty list.');
    return const [];
  }

  _logInfo('competitorsListProvider', 'Fetching competitors for userId: $userId');
  final repository = ref.watch(competitorsRepositoryProvider);
  
  try {
    return await repository.getAll(userId: userId);
  } catch (e, stack) {
    _logError('competitorsListProvider', 'Failed to fetch: $e''competitorsStatsProvider', 'No user logged in. Returning empty stats.');
    return CompetitorStats.empty;
  }

  final repository = ref.watch(competitorsRepositoryProvider);
  
  try {
    return await repository.getStats(userId: userId);
  } catch (e, stack) {
    _logError('competitorsStatsProvider', 'Failed to fetch stats: $e''''').toLowerCase();
            final domain = (c.domain ?? '''addCompetitorProvider', 'No user logged in');
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
      _logError('addCompetitorProvider', 'Unexpected error: $e''deleteCompetitorProvider', 'No user logged in');
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
    _logError('deleteCompetitorProvider', 'Unexpected error: $e''updateCompetitorProvider', 'No user logged in');
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
      _logError('updateCompetitorProvider', 'Unexpected error: $e''deleteManyCompetitorsProvider', 'No user logged in');
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
    _logError('deleteManyCompetitorsProvider', 'Unexpected error: $e''refreshCompetitorsProvider', 'Manual refresh triggered''✅ [$provider] $message');
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
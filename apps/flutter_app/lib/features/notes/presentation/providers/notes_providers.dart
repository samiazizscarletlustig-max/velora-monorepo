import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/notes_repository.dart';

// ═══════════════════════════════════════════
// Repository Provider
// ═══════════════════════════════════════════

/// Provider للـ Repository (Singleton)
final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository();
});

// ═══════════════════════════════════════════
// Data Providers
// ═══════════════════════════════════════════

/// Provider لجلب كل الملاحظات
final notesListProvider = FutureProvider<List<Note>>((ref) async {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.getAll();
});

/// Provider لإحصائيات الملاحظات
final notesStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.getStats();
});

// ═══════════════════════════════════════════
// Filter & Search Providers
// ═══════════════════════════════════════════

/// Search query
final notesSearchQueryProvider = StateProvider<String>((ref) => '');

/// Selected tag filter (null = all)
final notesSelectedTagProvider = StateProvider<String?>((ref) => null);

/// Current view mode: 'all' | 'pinned' | 'tags'
final notesViewModeProvider = StateProvider<String>((ref) => 'all');

/// Provider لجمع كل الـ tags الفريدة من كل الملاحظات
final allUniqueTagsProvider = Provider<List<String>>((ref) {
  final notesAsync = ref.watch(notesListProvider);
  
  return notesAsync.whenOrNull(
        data: (notes) {
          final tags = <String>{};
          for (final note in notes) {
            tags.addAll(note.tags);
          }
          return tags.toList()..sort();
        },
      ) ??
      [];
});

/// Provider للملاحظات المفلترة (حسب البحث + الـ tag + الـ view mode)
final filteredNotesProvider = Provider<List<Note>>((ref) {
  final notesAsync = ref.watch(notesListProvider);
  final searchQuery = ref.watch(notesSearchQueryProvider).toLowerCase();
  final selectedTag = ref.watch(notesSelectedTagProvider);
  final viewMode = ref.watch(notesViewModeProvider);

  return notesAsync.whenOrNull(
        data: (notes) {
          var filtered = notes;

          // 1. Filter by view mode (all / pinned)
          if (viewMode == 'pinned') {
            filtered = filtered.where((n) => n.isPinned).toList();
          }

          // 2. Filter by selected tag
          if (selectedTag != null) {
            filtered = filtered.where((n) => n.tags.contains(selectedTag)).toList();
          }

          // 3. Filter by search query
          if (searchQuery.isNotEmpty) {
            filtered = filtered.where((n) {
              final title = n.title.toLowerCase();
              final content = n.content.toLowerCase();
              final tags = n.tags.join(' ').toLowerCase();
              return title.contains(searchQuery) ||
                  content.contains(searchQuery) ||
                  tags.contains(searchQuery);
            }).toList();
          }

          return filtered;
        },
      ) ??
      [];
});

// ═══════════════════════════════════════════
// Currently Selected Note (for editor)
// ═══════════════════════════════════════════

/// Provider للملاحظة المحددة حالياً في الـ editor
final selectedNoteProvider = StateProvider<Note?>((ref) => null);

/// Provider لتتبع حالة "قيد التعديل" (unsaved changes)
final hasUnsavedChangesProvider = StateProvider<bool>((ref) => false);

// ═══════════════════════════════════════════
// Action Providers
// ═══════════════════════════════════════════

/// Provider لإنشاء ملاحظة جديدة
final createNoteProvider = FutureProvider.autoDispose<Note?>((ref) async {
  final repository = ref.read(notesRepositoryProvider);
  final result = await repository.create(
    title: 'Untitled Note',
    content: '',
    icon: '📝',
  );

  if (result != null) {
    // Refresh the list after successful creation
    ref.invalidate(notesListProvider);
    ref.invalidate(notesStatsProvider);
  }
  return result;
});

/// Provider لإنشاء ملاحظة جديدة (مع معطيات مخصصة)
class CreateNoteParams {
  final String title;
  final String content;
  final String icon;
  final List<String> tags;
  final String? linkedCompetitorId;
  final String? linkedInsightId;

  CreateNoteParams({
    required this.title,
    this.content = '',
    this.icon = '📝',
    this.tags = const [],
    this.linkedCompetitorId,
    this.linkedInsightId,
  });
}

final createNoteWithParamsProvider =
    FutureProvider.autoDispose.family<Note?, CreateNoteParams>(
  (ref, params) async {
    final repository = ref.read(notesRepositoryProvider);
    final result = await repository.create(
      title: params.title,
      content: params.content,
      icon: params.icon,
      tags: params.tags,
      linkedCompetitorId: params.linkedCompetitorId,
      linkedInsightId: params.linkedInsightId,
    );

    if (result != null) {
      ref.invalidate(notesListProvider);
      ref.invalidate(notesStatsProvider);
    }
    return result;
  },
);

/// Provider لحفظ سريع (auto-save) - title أو content فقط
class QuickSaveParams {
  final String id;
  final String? title;
  final String? content;

  QuickSaveParams({
    required this.id,
    this.title,
    this.content,
  });
}

final quickSaveNoteProvider =
    FutureProvider.autoDispose.family<bool, QuickSaveParams>(
  (ref, params) async {
    final repository = ref.read(notesRepositoryProvider);
    final result = await repository.quickSave(
      params.id,
      title: params.title,
      content: params.content,
    );

    if (result) {
      // Refresh list quietly (no loading indicator)
      ref.invalidate(notesListProvider);
    }
    return result;
  },
);

/// Provider لحفظ ملاحظة كاملة (كل الحقول)
class UpdateNoteParams {
  final String id;
  final Note note;

  UpdateNoteParams({
    required this.id,
    required this.note,
  });
}

final updateNoteProvider =
    FutureProvider.autoDispose.family<bool, UpdateNoteParams>(
  (ref, params) async {
    final repository = ref.read(notesRepositoryProvider);
    final result = await repository.update(params.id, params.note);

    if (result != null) {
      ref.invalidate(notesListProvider);
      ref.invalidate(notesStatsProvider);
    }
    return result != null;
  },
);

/// Provider لـ Pin/Unpin ملاحظة
class TogglePinParams {
  final String id;
  final bool isPinned;

  TogglePinParams({
    required this.id,
    required this.isPinned,
  });
}

final togglePinProvider =
    FutureProvider.autoDispose.family<bool, TogglePinParams>(
  (ref, params) async {
    final repository = ref.read(notesRepositoryProvider);
    final result = await repository.togglePin(params.id, params.isPinned);

    if (result) {
      ref.invalidate(notesListProvider);
      ref.invalidate(notesStatsProvider);
    }
    return result;
  },
);

/// Provider لحذف ملاحظة
final deleteNoteProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, id) async {
  final repository = ref.read(notesRepositoryProvider);
  final result = await repository.delete(id);

  if (result) {
    ref.invalidate(notesListProvider);
    ref.invalidate(notesStatsProvider);
    
    // إذا كانت الملاحظة المحذوفة هي المحددة حالياً، ألغِ التحديد
    final selected = ref.read(selectedNoteProvider);
    if (selected?.id == id) {
      ref.read(selectedNoteProvider.notifier).state = null;
    }
  }
  return result;
});
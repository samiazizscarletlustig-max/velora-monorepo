import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/notes_repository.dart''');

/// Selected tag filter (null = all)
final notesSelectedTagProvider = StateProvider<String?>((ref) => null);

/// Current view mode: 'all' | 'pinned' | 'tags'
final notesViewModeProvider = StateProvider<String>((ref) => 'all''pinned') {
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
              final tags = n.tags.join(' ''Untitled Note',
    content: '',
    icon: '📝''',
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

/// Provider لSave سريع (auto-save) - title أو content فقط
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

/// Provider لSave مNoحظة كاملة (كل الحقول)
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

/// Provider لـ Pin/Unpin مNoحظة
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

/// Provider لDelete مNoحظة
final deleteNoteProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, id) async {
  final repository = ref.read(notesRepositoryProvider);
  final result = await repository.delete(id);

  if (result) {
    ref.invalidate(notesListProvider);
    ref.invalidate(notesStatsProvider);
    
    // 
    final selected = ref.read(selectedNoteProvider);
    if (selected?.id == id) {
      ref.read(selectedNoteProvider.notifier).state = null;
    }
  }
  return result;
});
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../../shared/widgets/velora_card.dart';
import '../providers/notes_providers.dart';
import '../../data/notes_repository.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _searchController = TextEditingController();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  Timer? _autoSaveTimer;
  bool _isPreviewMode = false;

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _autoSaveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedNote = ref.watch(selectedNoteProvider);
    final filteredNotes = ref.watch(filteredNotesProvider);
    final statsAsync = ref.watch(notesStatsProvider);

    // Sync controllers when selected note changes
    ref.listen<Note?>(selectedNoteProvider, (previous, next) {
      if (next != null && next.id != previous?.id) {
        _titleController.text = next.title;
        _contentController.text = next.content;
        setState(() {
          _isPreviewMode = false;
        });
      } else if (next == null) {
        _titleController.clear();
        _contentController.clear();
      }
    });

    return Scaffold(
      body: Row(
        children: [
          // ═══ Sidebar (Notes List) ═══
          SizedBox(
            width: 360,
            child: _Sidebar(
              searchController: _searchController,
              filteredNotes: filteredNotes,
              statsAsync: statsAsync,
              onNoteSelected: (note) {
                ref.read(selectedNoteProvider.notifier).state = note;
              },
              onNewNote: () => _createNewNote(),
            ),
          ),

          // ═══ Divider ═══
          Container(
            width: 1,
            color: theme.colorScheme.outlineVariant,
          ),

          // ═══ Editor Panel ═══
          Expanded(
            child: selectedNote != null
                ? _EditorPanel(
                    note: selectedNote,
                    titleController: _titleController,
                    contentController: _contentController,
                    isPreviewMode: _isPreviewMode,
                    onTogglePreview: () {
                      setState(() {
                        _isPreviewMode = !_isPreviewMode;
                      });
                    },
                    onContentChanged: (value) => _scheduleAutoSave(content: value),
                    onTitleChanged: (value) => _scheduleAutoSave(title: value),
                    onDelete: () => _deleteNote(selectedNote),
                    onTogglePin: () => _togglePin(selectedNote),
                  )
                : _EmptyEditor(),
          ),
        ],
      ),
    );
  }

  void _scheduleAutoSave({String? title, String? content}) {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 500), () {
      final selectedNote = ref.read(selectedNoteProvider);
      if (selectedNote != null) {
        ref.read(
          quickSaveNoteProvider(
            QuickSaveParams(
              id: selectedNote.id,
              title: title,
              content: content,
            ),
          ),
        );
      }
    });
  }

  Future<void> _createNewNote() async {
    final result = await ref.read(createNoteProvider.future);
    if (result != null) {
      ref.read(selectedNoteProvider.notifier).state = result;
    }
  }

  Future<void> _deleteNote(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('notes.delete_title'.tr()),
        content: Text('notes.delete_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(deleteNoteProvider(note.id).future);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('notes.deleted_success'.tr())),
        );
      }
    }
  }

  Future<void> _togglePin(Note note) async {
    await ref.read(
      togglePinProvider(
        TogglePinParams(id: note.id, isPinned: !note.isPinned),
      ).future,
    );
    if (mounted) {
      // Update the selected note locally
      final updatedNote = Note(
        id: note.id,
        title: note.title,
        content: note.content,
        summary: note.summary,
        icon: note.icon,
        isPinned: !note.isPinned,
        tags: note.tags,
        linkedCompetitorId: note.linkedCompetitorId,
        linkedInsightId: note.linkedInsightId,
        createdAt: note.createdAt,
        updatedAt: DateTime.now(),
      );
      ref.read(selectedNoteProvider.notifier).state = updatedNote;
    }
  }
}

// ═══════════════════════════════════════════
// Sidebar Widget (Notes List)
// ═══════════════════════════════════════════

class _Sidebar extends ConsumerWidget {
  final TextEditingController searchController;
  final List<Note> filteredNotes;
  final AsyncValue<Map<String, int>> statsAsync;
  final Function(Note) onNoteSelected;
  final VoidCallback onNewNote;

  const _Sidebar({
    required this.searchController,
    required this.filteredNotes,
    required this.statsAsync,
    required this.onNoteSelected,
    required this.onNewNote,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedNote = ref.watch(selectedNoteProvider);
    final viewMode = ref.watch(notesViewModeProvider);
    final allTags = ref.watch(allUniqueTagsProvider);
    final selectedTag = ref.watch(notesSelectedTagProvider);

    return Column(
      children: [
        // ═══ Header ═══
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'notes.title'.tr(),
                    style: theme.textTheme.titleLarge,
                  ),
                  IconButton(
                    onPressed: onNewNote,
                    icon: const Icon(Icons.add),
                    tooltip: 'notes.new_note'.tr(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Search Bar
              VeloraCard(
                padding: EdgeInsets.zero,
                child: TextField(
                  controller: searchController,
                  onChanged: (value) {
                    ref.read(notesSearchQueryProvider.notifier).state = value;
                  },
                  decoration: InputDecoration(
                    hintText: 'notes.search_hint'.tr(),
                    prefixIcon: Icon(
                      Icons.search,
                      color: theme.colorScheme.secondary,
                    ),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              searchController.clear();
                              ref.read(notesSearchQueryProvider.notifier).state = '';
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // View Mode Tabs
              Row(
                children: [
                  _ViewModeTab(
                    label: 'notes.all'.tr(),
                    isSelected: viewMode == 'all',
                    onTap: () => ref.read(notesViewModeProvider.notifier).state = 'all',
                  ),
                  const SizedBox(width: 8),
                  _ViewModeTab(
                    label: 'notes.pinned'.tr(),
                    isSelected: viewMode == 'pinned',
                    onTap: () => ref.read(notesViewModeProvider.notifier).state = 'pinned',
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Tags Filter (if any)
              if (allTags.isNotEmpty)
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _TagChip(
                        label: 'All',
                        isSelected: selectedTag == null,
                        onTap: () => ref.read(notesSelectedTagProvider.notifier).state = null,
                      ),
                      const SizedBox(width: 6),
                      ...allTags.map((tag) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _TagChip(
                              label: tag,
                              isSelected: selectedTag == tag,
                              onTap: () => ref.read(notesSelectedTagProvider.notifier).state = tag,
                            ),
                          )),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // ═══ Notes List ═══
        Expanded(
          child: filteredNotes.isEmpty
              ? _EmptyNotesList()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  itemCount: filteredNotes.length,
                  itemBuilder: (context, index) {
                    final note = filteredNotes[index];
                    final isSelected = selectedNote?.id == note.id;
                    return _NoteCard(
                      note: note,
                      isSelected: isSelected,
                      onTap: () => onNoteSelected(note),
                    );
                  },
                ),
        ),

        // ═══ Stats Bar ═══
        statsAsync.whenOrNull(
              data: (stats) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  border: Border(
                    top: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                      icon: Icons.note,
                      label: stats['total'].toString(),
                    ),
                    _StatItem(
                      icon: Icons.push_pin,
                      label: stats['pinned'].toString(),
                    ),
                    _StatItem(
                      icon: Icons.tag,
                      label: stats['uniqueTags'].toString(),
                    ),
                    _StatItem(
                      icon: Icons.text_fields,
                      label: stats['totalWords'].toString(),
                    ),
                  ],
                ),
              ),
            ) ??
            const SizedBox.shrink(),
      ],
    );
  }
}

// ═══════════════════════════════════════════
// Editor Panel Widget
// ═══════════════════════════════════════════

class _EditorPanel extends StatelessWidget {
  final Note note;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final bool isPreviewMode;
  final VoidCallback onTogglePreview;
  final Function(String) onContentChanged;
  final Function(String) onTitleChanged;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;

  const _EditorPanel({
    required this.note,
    required this.titleController,
    required this.contentController,
    required this.isPreviewMode,
    required this.onTogglePreview,
    required this.onContentChanged,
    required this.onTitleChanged,
    required this.onDelete,
    required this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // ═══ Toolbar ═══
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              // Pin button
              IconButton(
                onPressed: onTogglePin,
                icon: Icon(
                  note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: note.isPinned ? const Color(0xFFF59E0B) : null,
                ),
                tooltip: note.isPinned ? 'notes.unpin'.tr() : 'notes.pin'.tr(),
              ),
              const SizedBox(width: 8),

              // Preview toggle
              IconButton(
                onPressed: onTogglePreview,
                icon: Icon(
                  isPreviewMode ? Icons.edit : Icons.visibility,
                ),
                tooltip: isPreviewMode ? 'notes.edit_mode'.tr() : 'notes.preview_mode'.tr(),
              ),
              const Spacer(),

              // Word count
              Text(
                '${note.wordCount} words',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 16),

              // Delete button
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                color: const Color(0xFFEF4444),
                tooltip: 'common.delete'.tr(),
              ),
            ],
          ),
        ),

        // ═══ Editor Content ═══
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                TextField(
                  controller: titleController,
                  onChanged: onTitleChanged,
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Untitled Note',
                    border: InputBorder.none,
                    hintStyle: theme.textTheme.displayLarge?.copyWith(
                      fontSize: 32,
                      color: theme.colorScheme.secondary.withOpacity(0.5),
                    ),
                  ),
                  maxLines: null,
                ),
                const SizedBox(height: 8),

                // Metadata
                Row(
                  children: [
                    Text(
                      note.updatedAgoFormatted,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                    if (note.tags.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      ...note.tags.map((tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '#$tag',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF4F46E5),
                                fontSize: 11,
                              ),
                            ),
                          )),
                    ],
                  ],
                ),
                const SizedBox(height: 24),

                // Content (Editor or Preview)
                if (isPreviewMode)
                  MarkdownBody(
                    data: contentController.text,
                    styleSheet: MarkdownStyleSheet(
                      p: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                      h1: theme.textTheme.displayLarge?.copyWith(fontSize: 28),
                      h2: theme.textTheme.displayLarge?.copyWith(fontSize: 24),
                      h3: theme.textTheme.displayLarge?.copyWith(fontSize: 20),
                      code: TextStyle(
                        backgroundColor: theme.colorScheme.surfaceVariant,
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )
                else
                  TextField(
                    controller: contentController,
                    onChanged: onContentChanged,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                      fontFamily: 'monospace',
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Start writing...',
                      border: InputBorder.none,
                      hintStyle: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.secondary.withOpacity(0.5),
                      ),
                    ),
                    maxLines: null,
                    minLines: 20,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════
// Empty Editor Widget
// ═══════════════════════════════════════════

class _EmptyEditor extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_add_outlined,
            size: 80,
            color: theme.colorScheme.secondary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'notes.no_note_selected'.tr(),
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'notes.select_or_create'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.secondary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Note Card Widget (Sidebar)
// ═══════════════════════════════════════════

class _NoteCard extends StatelessWidget {
  final Note note;
  final bool isSelected;
  final VoidCallback onTap;

  const _NoteCard({
    required this.note,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF4F46E5).withOpacity(0.1)
                : theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: const Color(0xFF4F46E5), width: 1.5)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(note.icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (note.isPinned)
                    const Icon(
                      Icons.push_pin,
                      size: 14,
                      color: Color(0xFFF59E0B),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                note.autoSummary,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    note.updatedAgoFormatted,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${note.wordCount}w',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                  if (note.tags.isNotEmpty) ...[
                    const Spacer(),
                    Text(
                      '#${note.tags.first}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF4F46E5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Helper Widgets
// ═══════════════════════════════════════════

class _ViewModeTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ViewModeTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isSelected ? const Color(0xFF4F46E5) : theme.colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TagChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isSelected ? Colors.white : theme.colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatItem({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.secondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyNotesList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_outlined,
            size: 56,
            color: theme.colorScheme.secondary.withOpacity(0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'notes.no_notes'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'notes.create_first'.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.secondary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
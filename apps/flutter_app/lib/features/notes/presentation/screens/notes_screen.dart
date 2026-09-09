import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_colors.dart';
import '../../../../core/widgets/premium_widgets.dart';
import '../../../../core/extensions/widget_extensions.dart';
import '../providers/notes_providers.dart';
import '../../data/notes_repository.dart';

// ═══════════════════════════════════════════════════════════
// 📝 NOTES SCREEN — PERFECTION EDITION
// Strategic knowledge base with premium editor.
// ═══════════════════════════════════════════════════════════
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  Timer? _autoSaveTimer;
  bool _isPreviewMode = false;
  bool _isSaving = false;
  bool _sidebarVisible = true;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _autoSaveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedNote = ref.watch(selectedNoteProvider);
    final filteredNotes = ref.watch(filteredNotesProvider);
    final statsAsync = ref.watch(notesStatsProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;

    ref.listen<Note?>(selectedNoteProvider, (previous, next) {
      if (next != null && next.id != previous?.id) {
        _titleController.text = next.title;
        _contentController.text = next.content;
        setState(() => _isPreviewMode = false);
      } else if (next == null) {
        _titleController.clear();
        _contentController.clear();
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedGradientBackground(
        child: isMobile
            ? _MobileLayout(
                searchController: _searchController,
                searchFocusNode: _searchFocusNode,
                titleController: _titleController,
                contentController: _contentController,
                filteredNotes: filteredNotes,
                statsAsync: statsAsync,
                selectedNote: selectedNote,
                isPreviewMode: _isPreviewMode,
                isSaving: _isSaving,
                onNewNote: _createNewNote,
                onNoteSelected: (note) {
                  ref.read(selectedNoteProvider.notifier).state = note;
                },
                onTogglePreview: () => setState(() => _isPreviewMode = !_isPreviewMode),
                onContentChanged: (value) => _scheduleAutoSave(content: value),
                onTitleChanged: (value) => _scheduleAutoSave(title: value),
                onDelete: () => selectedNote != null ? _deleteNote(selectedNote) : null,
                onTogglePin: () => selectedNote != null ? _togglePin(selectedNote) : null,
              )
            : Row(children: [
                if (_sidebarVisible)
                  SizedBox(
                    width: 380,
                    child: _Sidebar(
                      searchController: _searchController,
                      searchFocusNode: _searchFocusNode,
                      filteredNotes: filteredNotes,
                      statsAsync: statsAsync,
                      onNoteSelected: (note) {
                        ref.read(selectedNoteProvider.notifier).state = note;
                      },
                      onNewNote: _createNewNote,
                    ),
                  ),
                Container(
                  width: 1,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder,
                ),
                Expanded(
                  child: Column(children: [
                    _Toolbar(
                      onToggleSidebar: () => setState(() => _sidebarVisible = !_sidebarVisible),
                      sidebarVisible: _sidebarVisible,
                    ),
                    Expanded(
                      child: selectedNote != null
                          ? _EditorPanel(
                              note: selectedNote,
                              titleController: _titleController,
                              contentController: _contentController,
                              isPreviewMode: _isPreviewMode,
                              isSaving: _isSaving,
                              onTogglePreview: () => setState(() => _isPreviewMode = !_isPreviewMode),
                              onContentChanged: (value) => _scheduleAutoSave(content: value),
                              onTitleChanged: (value) => _scheduleAutoSave(title: value),
                              onDelete: () => _deleteNote(selectedNote),
                              onTogglePin: () => _togglePin(selectedNote),
                            )
                          : const _EmptyEditor(),
                    ),
                  ]),
                ),
              ]),
      ),
    );
  }

  void _scheduleAutoSave({String? title, String? content}) {
    setState(() => _isSaving = true);
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 500), () async {
      final selectedNote = ref.read(selectedNoteProvider);
      if (selectedNote != null) {
        await ref.read(
          quickSaveNoteProvider(
            QuickSaveParams(
              id: selectedNote.id,
              title: title,
              content: content,
            ),
          ).future,
        );
        if (mounted) setState(() => _isSaving = false);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          padding: const EdgeInsets.all(28),
          animate: false,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 22),
              ),
              const SizedBox(width: 14),
              Text(
                'notes.delete_title'.tr(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ]),
            const SizedBox(height: 20),
            Text(
              'notes.delete_confirm'.tr(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Text(note.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    note.title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('common.cancel'.tr()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.dangerGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('common.delete'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );

    if (confirmed == true) {
      await ref.read(deleteNoteProvider(note.id).future);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
              const SizedBox(width: 10),
              Text('notes.deleted_success'.tr(), style: const TextStyle(fontWeight: FontWeight.w500)),
            ]),
            backgroundColor: AppColors.darkSurface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            Icon(
              updatedNote.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              color: updatedNote.isPinned ? AppColors.warning : AppColors.info,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              updatedNote.isPinned ? 'Note pinned' : 'Note unpinned',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ]),
          backgroundColor: AppColors.darkSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════
// 📱 MOBILE LAYOUT (Collapsed sidebar)
// ═══════════════════════════════════════════════════════════
class _MobileLayout extends ConsumerStatefulWidget {
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final List<Note> filteredNotes;
  final AsyncValue<Map<String, int>> statsAsync;
  final Note? selectedNote;
  final bool isPreviewMode;
  final bool isSaving;
  final VoidCallback onNewNote;
  final Function(Note) onNoteSelected;
  final VoidCallback onTogglePreview;
  final Function(String) onContentChanged;
  final Function(String) onTitleChanged;
  final VoidCallback? onDelete;
  final VoidCallback? onTogglePin;

  const _MobileLayout({
    required this.searchController,
    required this.searchFocusNode,
    required this.titleController,
    required this.contentController,
    required this.filteredNotes,
    required this.statsAsync,
    required this.selectedNote,
    required this.isPreviewMode,
    required this.isSaving,
    required this.onNewNote,
    required this.onNoteSelected,
    required this.onTogglePreview,
    required this.onContentChanged,
    required this.onTitleChanged,
    this.onDelete,
    this.onTogglePin,
  });

  @override
  ConsumerState<_MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends ConsumerState<_MobileLayout> {
  bool _showSidebar = true;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (_showSidebar || widget.selectedNote == null)
        Expanded(
          child: _Sidebar(
            searchController: widget.searchController,
            searchFocusNode: widget.searchFocusNode,
            filteredNotes: widget.filteredNotes,
            statsAsync: widget.statsAsync,
            onNoteSelected: (note) {
              widget.onNoteSelected(note);
              setState(() => _showSidebar = false);
            },
            onNewNote: widget.onNewNote,
          ),
        )
      else
        Expanded(
          child: Column(children: [
            _MobileToolbar(
              onBack: () => setState(() => _showSidebar = true),
              isPreviewMode: widget.isPreviewMode,
              isSaving: widget.isSaving,
              onTogglePreview: widget.onTogglePreview,
              onDelete: widget.onDelete,
              onTogglePin: widget.onTogglePin,
            ),
            Expanded(
              child: _EditorPanel(
                note: widget.selectedNote!,
                titleController: widget.titleController,
                contentController: widget.contentController,
                isPreviewMode: widget.isPreviewMode,
                isSaving: widget.isSaving,
                onTogglePreview: widget.onTogglePreview,
                onContentChanged: widget.onContentChanged,
                onTitleChanged: widget.onTitleChanged,
                onDelete: () => widget.onDelete?.call(),
                onTogglePin: () => widget.onTogglePin?.call(),
                isMobile: true,
              ),
            ),
          ]),
        ),
    ]);
  }
}

class _MobileToolbar extends StatelessWidget {
  final VoidCallback onBack;
  final bool isPreviewMode;
  final bool isSaving;
  final VoidCallback onTogglePreview;
  final VoidCallback? onDelete;
  final VoidCallback? onTogglePin;

  const _MobileToolbar({
    required this.onBack,
    required this.isPreviewMode,
    required this.isSaving,
    required this.onTogglePreview,
    this.onDelete,
    this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: Row(children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const Spacer(),
        if (isSaving)
          const _AutoSaveIndicator()
        else
          const SizedBox.shrink(),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onTogglePin,
          icon: const Icon(Icons.push_pin_outlined),
        ),
        IconButton(
          onPressed: onTogglePreview,
          icon: Icon(isPreviewMode ? Icons.edit_rounded : Icons.visibility_rounded),
        ),
        IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🔧 TOOLBAR (Desktop)
// ═══════════════════════════════════════════════════════════
class _Toolbar extends StatelessWidget {
  final VoidCallback onToggleSidebar;
  final bool sidebarVisible;

  const _Toolbar({
    required this.onToggleSidebar,
    required this.sidebarVisible,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: Row(children: [
        IconButton(
          onPressed: onToggleSidebar,
          icon: Icon(
            sidebarVisible ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
            color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
          ),
          tooltip: sidebarVisible ? 'Hide sidebar' : 'Show sidebar',
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.purple.withOpacity(0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.edit_note_rounded, size: 14, color: Color(0xFF8B5CF6)),
            const SizedBox(width: 6),
            const Text(
              'Strategic Notes',
              style: TextStyle(
                color: Color(0xFF8B5CF6),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 📚 SIDEBAR (Notes List)
// ═══════════════════════════════════════════════════════════
class _Sidebar extends ConsumerWidget {
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final List<Note> filteredNotes;
  final AsyncValue<Map<String, int>> statsAsync;
  final Function(Note) onNoteSelected;
  final VoidCallback onNewNote;

  const _Sidebar({
    required this.searchController,
    required this.searchFocusNode,
    required this.filteredNotes,
    required this.statsAsync,
    required this.onNoteSelected,
    required this.onNewNote,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedNote = ref.watch(selectedNoteProvider);
    final viewMode = ref.watch(notesViewModeProvider);
    final allTags = ref.watch(allUniqueTagsProvider);
    final selectedTag = ref.watch(notesSelectedTagProvider);

    return Container(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: Column(children: [
        // ═══ Header ═══
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.pinkGradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.purple.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.sticky_note_2_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'notes.title'.tr(),
                  style: GoogleFonts.sora(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  ),
                ),
              ),
              GradientButton(
                text: 'New',
                icon: Icons.add_rounded,
                height: 36,
                onPressed: onNewNote,
              ),
            ]),
            const SizedBox(height: 16),

            // Search
            _PremiumSearchBar(
              controller: searchController,
              focusNode: searchFocusNode,
              onChanged: (value) {
                ref.read(notesSearchQueryProvider.notifier).state = value;
              },
              onClear: () {
                searchController.clear();
                ref.read(notesSearchQueryProvider.notifier).state = '';
              },
              totalCount: filteredNotes.length,
            ),
            const SizedBox(height: 12),

            // View Mode Tabs
            Row(children: [
              Expanded(
                child: _PremiumTab(
                  label: 'notes.all'.tr(),
                  icon: Icons.notes_rounded,
                  isSelected: viewMode == 'all',
                  onTap: () => ref.read(notesViewModeProvider.notifier).state = 'all',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PremiumTab(
                  label: 'notes.pinned'.tr(),
                  icon: Icons.push_pin_rounded,
                  isSelected: viewMode == 'pinned',
                  onTap: () => ref.read(notesViewModeProvider.notifier).state = 'pinned',
                ),
              ),
            ]),

            // Tags Filter
            if (allTags.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  _PremiumTagChip(
                    label: 'All',
                    isSelected: selectedTag == null,
                    onTap: () => ref.read(notesSelectedTagProvider.notifier).state = null,
                  ),
                  const SizedBox(width: 6),
                  ...allTags.map((tag) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _PremiumTagChip(
                          label: '#$tag',
                          isSelected: selectedTag == tag,
                          onTap: () => ref.read(notesSelectedTagProvider.notifier).state = tag,
                        ),
                      )),
                ]),
              ),
            ],
          ]),
        ),

        // ═══ Notes List ═══
        Expanded(
          child: filteredNotes.isEmpty
              ? const _EmptyNotesList()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: filteredNotes.length,
                  itemBuilder: (context, index) {
                    final note = filteredNotes[index];
                    final isSelected = selectedNote?.id == note.id;
                    return _PremiumNoteCard(
                      note: note,
                      isSelected: isSelected,
                      onTap: () => onNoteSelected(note),
                    ).animate()
                      .fadeIn(
                        duration: 400.ms,
                        delay: Duration(milliseconds: 50 * index),
                      )
                      .slideX(begin: -0.05, end: 0);
                  },
                ),
        ),

        // ═══ Stats Bar ═══
        statsAsync.whenOrNull(
          data: (stats) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _MiniStat(icon: Icons.note_rounded, value: stats['total'] ?? 0, color: AppColors.purple),
              _MiniStat(icon: Icons.push_pin_rounded, value: stats['pinned'] ?? 0, color: AppColors.warning),
              _MiniStat(icon: Icons.tag_rounded, value: stats['uniqueTags'] ?? 0, color: AppColors.info),
              _MiniStat(icon: Icons.text_fields_rounded, value: stats['totalWords'] ?? 0, color: AppColors.success),
            ]),
          ),
        ) ?? const SizedBox.shrink(),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🔍 PREMIUM SEARCH BAR
// ═══════════════════════════════════════════════════════════
class _PremiumSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final int totalCount;

  const _PremiumSearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    required this.totalCount,
  });

  @override
  State<_PremiumSearchBar> createState() => _PremiumSearchBarState();
}

class _PremiumSearchBarState extends State<_PremiumSearchBar> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasQuery = widget.controller.text.isNotEmpty;

    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _focused
                ? AppColors.purple
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: _focused ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          const SizedBox(width: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              Icons.search_rounded,
              key: ValueKey(_focused),
              color: _focused
                  ? AppColors.purple
                  : (isDark ? AppColors.darkSecondary : AppColors.lightSecondary),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              onChanged: widget.onChanged,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Search notes...',
                hintStyle: TextStyle(
                  color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                  fontSize: 14,
                ),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (hasQuery) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: AppColors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${widget.totalCount}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8B5CF6),
                ),
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onClear,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.close_rounded,
                      color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                      size: 16),
                ),
              ),
            ),
          ] else
            const SizedBox(width: 12),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🏷️ PREMIUM TAB
// ═══════════════════════════════════════════════════════════
class _PremiumTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PremiumTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.purple.withOpacity(0.15)
                : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.purple.withOpacity(0.5) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? AppColors.purple
                  : (isDark ? AppColors.darkSecondary : AppColors.lightSecondary),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.purple
                    : (isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🏷️ PREMIUM TAG CHIP
// ═══════════════════════════════════════════════════════════
class _PremiumTagChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PremiumTagChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected ? AppColors.pinkGradient : null,
            color: isSelected
                ? null
                : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 📝 PREMIUM NOTE CARD
// ═══════════════════════════════════════════════════════════
class _PremiumNoteCard extends StatefulWidget {
  final Note note;
  final bool isSelected;
  final VoidCallback onTap;

  const _PremiumNoteCard({
    required this.note,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_PremiumNoteCard> createState() => _PremiumNoteCardState();
}

class _PremiumNoteCardState extends State<_PremiumNoteCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: AnimatedScale(
          scale: _hovering && !widget.isSelected ? 1.01 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? AppColors.purple.withOpacity(0.12)
                      : (_hovering
                          ? (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant)
                          : Colors.transparent),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.isSelected
                        ? AppColors.purple.withOpacity(0.5)
                        : (_hovering
                            ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                            : Colors.transparent),
                    width: 1.5,
                  ),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: widget.isSelected
                            ? AppColors.purple.withOpacity(0.15)
                            : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(widget.note.icon, style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          widget.note.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.note.updatedAgoFormatted,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                          ),
                        ),
                      ]),
                    ),
                    if (widget.note.isPinned)
                      Icon(Icons.push_pin_rounded, size: 16, color: AppColors.warning)
                          .animate(onPlay: (c) => c.repeat(period: 2.seconds))
                          .rotate(begin: -0.1, end: 0.1, duration: 500.ms)
                          .then()
                          .rotate(begin: 0.1, end: -0.1, duration: 500.ms),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    widget.note.autoSummary,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.note.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: widget.note.tags.take(3).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#$tag',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8B5CF6),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 📊 MINI STAT
// ═══════════════════════════════════════════════════════════
class _MiniStat extends StatelessWidget {
  final IconData icon;
  final int value;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      TweenAnimationBuilder<int>(
        tween: IntTween(begin: 0, end: value),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Text(
          v.toString(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════
// ✏️ EDITOR PANEL
// ═══════════════════════════════════════════════════════════
class _EditorPanel extends StatelessWidget {
  final Note note;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final bool isPreviewMode;
  final bool isSaving;
  final VoidCallback onTogglePreview;
  final Function(String) onContentChanged;
  final Function(String) onTitleChanged;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;
  final bool isMobile;

  const _EditorPanel({
    required this.note,
    required this.titleController,
    required this.contentController,
    required this.isPreviewMode,
    required this.isSaving,
    required this.onTogglePreview,
    required this.onContentChanged,
    required this.onTitleChanged,
    required this.onDelete,
    required this.onTogglePin,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      child: Column(children: [
        if (!isMobile)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
            child: Row(children: [
              _EditorActionButton(
                icon: note.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                label: note.isPinned ? 'Pinned' : 'Pin',
                color: note.isPinned ? AppColors.warning : null,
                onTap: onTogglePin,
              ),
              const SizedBox(width: 8),

              _EditorActionButton(
                icon: isPreviewMode ? Icons.edit_rounded : Icons.visibility_rounded,
                label: isPreviewMode ? 'Edit' : 'Preview',
                color: isPreviewMode ? AppColors.info : null,
                onTap: onTogglePreview,
              ),

              const Spacer(),

              if (isSaving) const _AutoSaveIndicator(),

              const SizedBox(width: 12),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.text_fields_rounded, size: 12, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    '${note.wordCount} words',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ]),
              ),

              const SizedBox(width: 12),

              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                tooltip: 'common.delete'.tr(),
              ),
            ]),
          ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: titleController,
                onChanged: onTitleChanged,
                style: GoogleFonts.sora(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  letterSpacing: -0.8,
                  height: 1.2,
                ),
                decoration: InputDecoration(
                  hintText: 'Untitled Note',
                  border: InputBorder.none,
                  hintStyle: GoogleFonts.sora(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: (isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withOpacity(0.4),
                    letterSpacing: -0.8,
                  ),
                ),
                maxLines: null,
              ),
              const SizedBox(height: 12),

              Row(children: [
                Icon(Icons.access_time_rounded,
                    size: 14,
                    color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary),
                const SizedBox(width: 6),
                Text(
                  note.updatedAgoFormatted,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (note.tags.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Wrap(
                    spacing: 6,
                    children: note.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: AppColors.pinkGradient,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '#$tag',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ]),

              const SizedBox(height: 24),

              Container(
                height: 1,
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),

              const SizedBox(height: 24),

              if (isPreviewMode)
                MarkdownBody(
                  data: contentController.text,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      fontSize: 15,
                      height: 1.7,
                      color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                    ),
                    h1: GoogleFonts.sora(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                    ),
                    h2: GoogleFonts.sora(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                    ),
                    h3: GoogleFonts.sora(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                    ),
                    code: TextStyle(
                      backgroundColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                      fontFamily: 'monospace',
                      fontSize: 14,
                      color: AppColors.purple,
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    blockquoteDecoration: BoxDecoration(
                      color: AppColors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.purple.withOpacity(0.3)),
                    ),
                    // ✅ FIXED: WrapAlignment instead of TextAlign
                    blockquoteAlign: WrapAlignment.start,
                    listBullet: const TextStyle(color: Color(0xFF8B5CF6)),
                  ),
                )
              else
                TextField(
                  controller: contentController,
                  onChanged: onContentChanged,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.7,
                    color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Start writing your strategic note...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      fontSize: 15,
                      color: (isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withOpacity(0.5),
                    ),
                  ),
                  maxLines: null,
                  minLines: 20,
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 💾 AUTO-SAVE INDICATOR
// ═══════════════════════════════════════════════════════════
class _AutoSaveIndicator extends StatelessWidget {
  const _AutoSaveIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.warning),
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'Saving...',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.warning,
          ),
        ),
      ]),
    ).animate().fadeIn();
  }
}

// ═══════════════════════════════════════════════════════════
// 🔧 EDITOR ACTION BUTTON
// ═══════════════════════════════════════════════════════════
class _EditorActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _EditorActionButton({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonColor = color ?? (isDark ? AppColors.darkPrimary : AppColors.lightPrimary);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color?.withOpacity(0.1) ?? Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: buttonColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: buttonColor,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🕳️ EMPTY STATES
// ═══════════════════════════════════════════════════════════
class _EmptyEditor extends StatelessWidget {
  const _EmptyEditor();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Stack(alignment: Alignment.center, children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.purple.withOpacity(0.15),
                AppColors.pink.withOpacity(0.1),
              ]),
              shape: BoxShape.circle,
            ),
          ).animate(onPlay: (c) => c.repeat(period: 3.seconds))
           .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 1500.ms)
           .then()
           .scale(begin: const Offset(1.05, 1.05), end: const Offset(0.95, 0.95), duration: 1500.ms),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppColors.pinkGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.purple.withOpacity(0.4),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 40),
          ),
        ]),
        const SizedBox(height: 32),
        Text(
          'notes.no_note_selected'.tr(),
          style: GoogleFonts.sora(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'notes.select_or_create'.tr(),
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
          ),
        ),
      ]),
    );
  }
}

class _EmptyNotesList extends StatelessWidget {
  const _EmptyNotesList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.purple.withOpacity(0.15),
              AppColors.pink.withOpacity(0.1),
            ]),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.note_add_rounded,
            size: 40,
            color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'notes.no_notes'.tr(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'notes.create_first'.tr(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
              ),
        ),
      ]),
    );
  }
}
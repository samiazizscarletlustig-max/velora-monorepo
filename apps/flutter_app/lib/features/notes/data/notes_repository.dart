import 'package:supabase_flutter/supabase_flutter.dart';

/// Data class للملاحظة
class Note {
  final String id;
  final String title;
  final String content;
  final String? summary;
  final String icon;
  final bool isPinned;
  final List<String> tags;
  final String? linkedCompetitorId;
  final String? linkedInsightId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    this.summary,
    this.icon = '📝',
    this.isPinned = false,
    this.tags = const [],
    this.linkedCompetitorId,
    this.linkedInsightId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Untitled Note',
      content: map['content'] as String? ?? '',
      summary: map['summary'] as String?,
      icon: map['icon'] as String? ?? '📝',
      isPinned: map['is_pinned'] as bool? ?? false,
      tags: (map['tags'] as List?)?.cast<String>() ?? [],
      linkedCompetitorId: map['linked_competitor_id'] as String?,
      linkedInsightId: map['linked_insight_id'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'summary': summary,
      'icon': icon,
      'is_pinned': isPinned,
      'tags': tags,
      'linked_competitor_id': linkedCompetitorId,
      'linked_insight_id': linkedInsightId,
    };
  }

  /// تنسيق التاريخ بالنسبي
  String get updatedAgoFormatted {
    final diff = DateTime.now().difference(updatedAt);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${diff.inDays ~/ 7}w ago';
  }

  /// استخراج عدد الكلمات
  int get wordCount {
    if (content.trim().isEmpty) return 0;
    return content.trim().split(RegExp(r'\s+')).length;
  }

  /// إنشاء summary تلقائي (أول 100 حرف)
  String get autoSummary {
    if (summary != null && summary!.isNotEmpty) return summary!;
    if (content.isEmpty) return '';
    final cleanContent = content.replaceAll(RegExp(r'[#*_`>\-\[\]]'), '');
    return cleanContent.length > 100 
        ? '${cleanContent.substring(0, 100)}...' 
        : cleanContent;
  }
}

/// Repository لإدارة الملاحظات
class NotesRepository {
  final SupabaseClient _client;

  NotesRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// جلب كل الملاحظات (مرتبة: pinned أولاً، ثم الأحدث)
  Future<List<Note>> getAll() async {
    try {
      final response = await _client
          .from('notes')
          .select('*')
          .order('is_pinned', ascending: false)
          .order('updated_at', ascending: false);

      return response.map((map) => Note.fromMap(map)).toList();
    } catch (e) {
      print('❌ Error fetching notes: $e');
      return [];
    }
  }

  /// جلب ملاحظة واحدة
  Future<Note?> getById(String id) async {
    try {
      final response = await _client
          .from('notes')
          .select('*')
          .eq('id', id)
          .single();

      return Note.fromMap(response);
    } catch (e) {
      print('❌ Error fetching note: $e');
      return null;
    }
  }

  /// إنشاء ملاحظة جديدة
  Future<Note?> create({
    required String title,
    String content = '',
    String icon = '📝',
    List<String> tags = const [],
    String? linkedCompetitorId,
    String? linkedInsightId,
  }) async {
    try {
      final response = await _client
          .from('notes')
          .insert({
            'title': title,
            'content': content,
            'icon': icon,
            'tags': tags,
            'linked_competitor_id': linkedCompetitorId,
            'linked_insight_id': linkedInsightId,
          })
          .select()
          .single();

      return Note.fromMap(response);
    } catch (e) {
      print('❌ Error creating note: $e');
      return null;
    }
  }

  /// تحديث ملاحظة
  Future<Note?> update(String id, Note note) async {
    try {
      final response = await _client
          .from('notes')
          .update(note.toMap())
          .eq('id', id)
          .select()
          .single();

      return Note.fromMap(response);
    } catch (e) {
      print('❌ Error updating note: $e');
      return null;
    }
  }

  /// حفظ سريع (title + content فقط)
  Future<bool> quickSave(String id, {String? title, String? content}) async {
    try {
      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (content != null) updates['content'] = content;
      
      if (updates.isEmpty) return true;

      await _client
          .from('notes')
          .update(updates)
          .eq('id', id);
      
      return true;
    } catch (e) {
      print('❌ Error quick saving: $e');
      return false;
    }
  }

  /// Pin/Unpin ملاحظة
  Future<bool> togglePin(String id, bool isPinned) async {
    try {
      await _client
          .from('notes')
          .update({'is_pinned': isPinned})
          .eq('id', id);
      return true;
    } catch (e) {
      print('❌ Error toggling pin: $e');
      return false;
    }
  }

  /// حذف ملاحظة
  Future<bool> delete(String id) async {
    try {
      await _client.from('notes').delete().eq('id', id);
      return true;
    } catch (e) {
      print('❌ Error deleting note: $e');
      return false;
    }
  }

  /// جلب الإحصائيات
  Future<Map<String, int>> getStats() async {
    try {
      final all = await _client.from('notes').select('id, is_pinned, tags');
      
      final pinned = all.where((n) => n['is_pinned'] == true).length;
      
      // جمع كل الـ tags الفريدة
      final allTags = <String>{};
      for (final note in all) {
        final tags = (note['tags'] as List?)?.cast<String>() ?? [];
        allTags.addAll(tags);
      }

      // عد الكلمات الكلي
      final wordsResponse = await _client.from('notes').select('content');
      int totalWords = 0;
      for (final note in wordsResponse) {
        final content = note['content'] as String? ?? '';
        if (content.trim().isNotEmpty) {
          totalWords += content.trim().split(RegExp(r'\s+')).length;
        }
      }

      return {
        'total': all.length,
        'pinned': pinned,
        'uniqueTags': allTags.length,
        'totalWords': totalWords,
      };
    } catch (e) {
      print('❌ Error getting stats: $e');
      return {
        'total': 0,
        'pinned': 0,
        'uniqueTags': 0,
        'totalWords': 0,
      };
    }
  }
}
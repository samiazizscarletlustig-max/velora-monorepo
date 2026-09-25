import 'package:supabase_flutter/supabase_flutter.dart''📝',
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
      'linked_insight_id''Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${diff.inDays ~/ 7}w ago''\s+''';
    final cleanContent = content.replaceAll(RegExp(r'[#*_`>\-\[\]]'), '');
    return cleanContent.length > 100 
        ? '${cleanContent.substring(0, 100)}...''notes')
          .select('*')
          .order('is_pinned', ascending: false)
          .order('updated_at', ascending: false);

      return response.map((map) => Note.fromMap(map)).toList();
    } catch (e) {
      print('❌ Error fetching notes: $e''notes')
          .select('*')
          .eq('id', id)
          .single();

      return Note.fromMap(response);
    } catch (e) {
      print('❌ Error fetching note: $e''',
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
      print('❌ Error creating note: $e''notes')
          .update(note.toMap())
          .eq('id', id)
          .select()
          .single();

      return Note.fromMap(response);
    } catch (e) {
      print('❌ Error updating note: $e''title'] = title;
      if (content != null) updates['content'] = content;
      
      if (updates.isEmpty) return true;

      await _client
          .from('notes')
          .update(updates)
          .eq('id', id);
      
      return true;
    } catch (e) {
      print('❌ Error quick saving: $e''notes')
          .update({'is_pinned': isPinned})
          .eq('id', id);
      return true;
    } catch (e) {
      print('❌ Error toggling pin: $e''notes').delete().eq('id', id);
      return true;
    } catch (e) {
      print('❌ Error deleting note: $e''notes').select('id, is_pinned, tags');
      
      final pinned = all.where((n) => n['is_pinned''tags''notes').select('content');
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
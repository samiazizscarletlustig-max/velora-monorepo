import 'package:supabase_flutter/supabase_flutter.dart''',
    this.aiRecommendation = '''id'] as String,
      title: map['title'] as String? ?? 'Untitled Insight',
      summary: map['summary'] as String? ?? '',
      detailedAnalysis: map['detailed_analysis'] as String? ?? '',
      aiRecommendation: map['ai_recommendation'] as String? ?? '''severity'] as String? ?? 'low').toLowerCase(),
      competitorName: map['competitor_name'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '''${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${diff.inDays ~/ 7}w ago''critical':
        return 'EF4444';
      case 'high':
        return 'F59E0B';
      case 'medium':
        return '3B82F6';
      default:
        return '10B981''ai_insights')
            .select('*, competitors(name)')
            .order('created_at', ascending: false)
            .limit(100);
        
        return response.map((map) {
          final competitorData = map['competitors'] as Map<String, dynamic>?;
          return AIInsight.fromMap({
            ...map,
            'competitor_name': competitorData?['name'],
          });
        }).toList();
      } catch (e) {
        print('⚠️ Join failed, fetching insights without competitor names: $e');
        response = await _client
            .from('ai_insights')
            .select('*')
            .order('created_at', ascending: false)
            .limit(100);
        
        return response.map((map) => AIInsight.fromMap(map)).toList();
      }
    } catch (e) {
      print('❌ Error fetching insights: $e''ai_insights')
          .select('*')
          .eq('severity', severity)
          .order('created_at', ascending: false)
          .limit(100);

      return response.map((map) => AIInsight.fromMap(map)).toList();
    } catch (e) {
      print('❌ Error fetching insights by severity: $e''ai_insights').select('id');
      
      final critical = await _client
          .from('ai_insights')
          .select('id')
          .eq('severity', 'critical');
      
      final high = await _client
          .from('ai_insights')
          .select('id')
          .eq('severity', 'high');
      
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final thisWeek = await _client
          .from('ai_insights')
          .select('id')
          .gte('created_at', weekAgo.toIso8601String());

      return {
        'total': all.length,
        'critical': critical.length,
        'high': high.length,
        'thisWeek': thisWeek.length,
      };
    } catch (e) {
      print('❌ Error getting insights stats: $e');
      return {
        'total': 0,
        'critical': 0,
        'high': 0,
        'thisWeek': 0,
      };
    }
  }

  /// Delete Insight
  Future<bool> deleteInsight(String id) async {
    try {
      await _client.from('ai_insights').delete().eq('id', id);
      return true;
    } catch (e) {
      print('❌ Error deleting insight: $e');
      return false;
    }
  }
}
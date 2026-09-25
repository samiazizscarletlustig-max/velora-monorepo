import 'package:supabase_flutter/supabase_flutter.dart''competitors')
          .select('id')
          .eq('user_id', userId);

      final competitorIds = competitorsRes.map((c) => c['id''products')
          .select('id')
          .inFilter('competitor_id''ai_insights')
          .select('id')
          .inFilter('competitor_id', competitorIds);
      
      final totalInsights = insightsRes.length;

      final avgProducts = totalCompetitors > 0 
          ? totalProducts / totalCompetitors 
          : 0.0;

      return AnalyticsStats(
        totalCompetitors: totalCompetitors,
        totalProducts: totalProducts,
        totalInsights: totalInsights,
        avgProductsPerCompetitor: double.parse(avgProducts.toStringAsFixed(1)),
      );
    } catch (e) {
      print('❌ Error getting analytics stats: $e''competitors')
          .select('id')
          .eq('user_id', userId);

      final competitorIds = competitorsRes.map((c) => c['id'] as String).toList();
      if (competitorIds.isEmpty) return [];

      final insights = await _client
          .from('ai_insights')
          .select('severity')
          .inFilter('competitor_id', competitorIds);

      final counts = <String, int>{
        'critical': 0,
        'high': 0,
        'medium': 0,
        'low': 0,
      };

      for (final insight in insights) {
        final severity = (insight['severity'] as String? ?? 'low').toLowerCase();
        if (counts.containsKey(severity)) {
          counts[severity] = counts[severity]! + 1;
        }
      }

      final colors = {
        'critical': 'EF4444',
        'high': 'F59E0B',
        'medium': '3B82F6',
        'low': '10B981',
      };

      return counts.entries
          .where((e) => e.value > 0)
          .map((e) => PieSlice(
                label: e.key[0].toUpperCase() + e.key.substring(1),
                value: e.value.toDouble(),
                colorHex: colors[e.key]!,
              ))
          .toList();
    } catch (e) {
      print('❌ Error getting insights distribution: $e''competitors')
          .select('id')
          .eq('user_id', userId);

      final competitorIds = competitorsRes.map((c) => c['id'] as String).toList();
      if (competitorIds.isEmpty) return [];

      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final insights = await _client
          .from('ai_insights')
          .select('created_at')
          .inFilter('competitor_id', competitorIds)
          .gte('created_at', thirtyDaysAgo.toIso8601String());

      final countsByDate = <String, int>{};
      for (final insight in insights) {
        final dateStr = insight['created_at'] as String;
        final date = DateTime.tryParse(dateStr);
        if (date != null) {
          final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          countsByDate[key] = (countsByDate[key] ?? 0) + 1;
        }
      }

      final points = countsByDate.entries.map((e) {
        final parts = e.key.split('-');
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        return ChartDataPoint(
          date: date,
          value: e.value.toDouble(),
        );
      }).toList();

      points.sort((a, b) => a.date.compareTo(b.date));
      return points;
    } catch (e) {
      print('❌ Error getting insights timeline: $e''competitors')
          .select('id, name')
          .eq('user_id', userId);

      final results = <ChartDataPoint>[];
      
      for (final competitor in competitorsRes) {
        final compId = competitor['id'] as String;
        final compName = competitor['name'] as String? ?? 'Unknown''products')
            .select('id')
            .eq('competitor_id''❌ Error getting top competitors: $e');
      return [];
    }
  }
}
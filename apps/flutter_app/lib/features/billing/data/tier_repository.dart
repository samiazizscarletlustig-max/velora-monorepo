import 'package:supabase_flutter/supabase_flutter.dart''free';

      final response = await Supabase.instance.client
          .from('users')
          .select('tier')
          .eq('id', user.id)
          .maybeSingle();

      return (response?['tier'] as String?) ?? 'free';
    } catch (e) {
      return 'free''pro':
        return 10;
      case 'pro_plus':
        return 25;
      case 'enterprise':
        return 9999;
      default:
        return 3;
    }
  }

  /// 
  static Future<bool> canAddCompetitor(int currentCount) async {
    final tier = await getCurrentUserTier();
    final max = getMaxCompetitors(tier);
    return currentCount < max;
  }
}
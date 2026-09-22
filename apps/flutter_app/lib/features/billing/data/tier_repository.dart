import 'package:supabase_flutter/supabase_flutter.dart';

class TierRepository {
  /// قراءة خطة المستخدم الحالي
  static Future<String> getCurrentUserTier() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return 'free';

      final response = await Supabase.instance.client
          .from('users')
          .select('tier')
          .eq('id', user.id)
          .maybeSingle();

      return (response?['tier'] as String?) ?? 'free';
    } catch (e) {
      return 'free';
    }
  }

  /// حدّ عدد المنافسين حسب الخطة
  static int getMaxCompetitors(String tier) {
    switch (tier) {
      case 'pro':
        return 10;
      case 'pro_plus':
        return 25;
      case 'enterprise':
        return 9999;
      default:
        return 3;
    }
  }

  /// هل يمكن للمستخدم إضافة منافس جديد؟
  static Future<bool> canAddCompetitor(int currentCount) async {
    final tier = await getCurrentUserTier();
    final max = getMaxCompetitors(tier);
    return currentCount < max;
  }
}
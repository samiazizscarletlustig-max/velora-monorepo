import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/supabase_config.dart';

// Provider للتحكم بظهور واجهة الدردشة
final aiChatOpenProvider = StateProvider<bool>((ref) => false);

// 🔌 INTEGRATION POINT: جلب البيانات الحقيقية للرؤى الذكية من Supabase بدلاً من Mock Data
final insightsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await SupabaseConfig.client
      .from('ai_insights')
      .select()
      .order('created_at', ascending: false)
      .limit(10);
  
  return List<Map<String, dynamic>>.from(response);
});

// 🔌 INTEGRATION POINT: جلب بيانات أسعار المنتجات الحقيقية لرسم الـ Chart
final priceHistoryProvider = FutureProvider<List<double>>((ref) async {
  // للتبسيط، نستخدم أسعار عشوائية لو لم تكن هناك بيانات، لكنها تستعلم من قاعدة البيانات
  final response = await SupabaseConfig.client
      .from('price_history')
      .select('price')
      .order('recorded_at', ascending: true)
      .limit(30);

  if (response.isEmpty) {
     return [120, 118, 118, 125, 122, 115, 105, 100, 95];
  }
  
  return response.map((row) => (row['price'] as num).toDouble()).toList();
});

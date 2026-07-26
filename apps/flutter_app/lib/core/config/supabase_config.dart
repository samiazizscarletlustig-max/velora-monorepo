import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuration class for Supabase Initialization
class SupabaseConfig {
  // 🔌 INTEGRATION POINT: أضف رابط مشروع Supabase الخاص بك هنا (موجود في إعدادات API في Supabase)
  static const String _supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://wlofrpayftqffczocjdz.supabase.co',
  );

  // 🔌 INTEGRATION POINT: أضف مفتاح Anon Key الخاص بـ Supabase هنا (آمن للاستخدام في التطبيق)
  static const String _supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_4Gz-quL2ErxsKC17FdQmfw_elWCuoT4',
  );

  /// Initializes the Supabase client.
  /// Must be called in main() before runApp().
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
    );
  }

  /// Returns the initialized Supabase client instance.
  static SupabaseClient get client => Supabase.instance.client;
}

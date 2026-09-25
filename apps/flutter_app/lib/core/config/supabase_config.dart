import 'package:supabase_flutter/supabase_flutter.dart''SUPABASE_URL',
    defaultValue: 'https://wlofrpayftqffcZocjdz.supabase.co''SUPABASE_ANON_KEY',
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
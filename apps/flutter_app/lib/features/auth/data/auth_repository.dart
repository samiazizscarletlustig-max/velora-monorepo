import 'package:supabase_flutter/supabase_flutter.dart''${Uri.base.origin}/''Google sign-in error: $e');
      return false;
    }
  }

  /// Register الLogout.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
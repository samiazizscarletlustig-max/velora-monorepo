import 'package:supabase_flutter/supabase_flutter.dart';

/// حالة المصادقة داخل تطبيقنا.
/// (سمّيناها AppAuthState حتى لا تتعارض مع AuthState الموجودة في مكتبة supabase)
class AppAuthState {
  final User? user;
  final bool isLoading;

  const AppAuthState({this.user, this.isLoading = false});

  /// هل المستخدم مسجّل دخول الآن؟
  bool get isAuthenticated => user != null;
}

/// الوسيط بين التطبيق و Supabase Auth.
class AuthRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// المستخدم الحالي (إن وُجدت جلسة محفوظة من قبل).
  User? get currentUser => _client.auth.currentUser;

  /// معرّف المستخدم الحالي (نستخدمه لاحقاً لربط البيانات).
  String? get currentUserId => currentUser?.id;

  /// بثّ حيّ: يخبر التطبيق فوراً عند الدخول أو الخروج.
  Stream<AppAuthState> get authStateChanges async* {
    // الحالة الحالية أولاً
    yield AppAuthState(user: currentUser, isLoading: false);

    // ثم نتابع كل تغيير
    await for (final event in _client.auth.onAuthStateChange) {
      yield AppAuthState(
        user: event.session?.user,
        isLoading: false,
      );
    }
  }

  /// ✅ تسجيل الدخول بـ Google فقط (ينشئ الحساب تلقائياً أول مرة).
  /// يفتح نافذة Google في الويب ويعيد التوجيه بعد المصادقة.
  Future<bool> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: '${Uri.base.origin}/', // ✅ إضافة / للتطابق مع Supabase
      );
      return true;
    } catch (e) {
      print('Google sign-in error: $e');
      return false;
    }
  }

  /// تسجيل الخروج.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
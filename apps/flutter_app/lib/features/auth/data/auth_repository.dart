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

  /// إنشاء حساب جديد.
  Future<User?> signUp({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
    );
    return response.user;
  }

  /// تسجيل الدخول.
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    return response.user;
  }

  /// تسجيل الخروج.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
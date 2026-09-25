import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository.dart';

/// Repository واحد (Singleton) مسؤول عن جميع عمليات المصادقة.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// البثّ الحيّ لحالة المصادقة.
/// أي تغيير (تسجيل دخول / خروج) سيصل مباشرة إلى جميع الشاشات
/// التي تستمع لهذا الـ Provider.
final authStateProvider = StreamProvider<AppAuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});
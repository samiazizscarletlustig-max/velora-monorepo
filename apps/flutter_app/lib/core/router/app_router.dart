import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/main_scaffold.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/competitors/presentation/screens/competitors_screen.dart';
import '../../features/insights/presentation/screens/insights_screen.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/notes/presentation/screens/notes_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// The router reacts to the authentication state:
/// - No session → forces to /auth
/// - With session → redirects away from /auth
final goRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final loggedIn = auth.whenOrNull(data: (s) => s.isAuthenticated) ?? false;
      final path = state.matchedLocation;
      final isAuthRoute = path == '/auth';

      // إذا لم يكن مسجل دخول، ويحاول الوصول لأي صفحة أخرى → أرسله إلى شاشة الدخول
      if (!loggedIn && !isAuthRoute) return '/auth';

      // إذا كان مسجل دخول، ويحاول الوصول إلى شاشة الدخول → أرسله إلى لوحة التحكم
      if (loggedIn && isAuthRoute) return '/dashboard';

      // غير ذلك → ابقَ حيث أنت
      return null;
    },
    routes: [
      // شاشة المصادقة (خارج Shell — بدون شريط جانبي)
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const AuthScreen(),
      ),

      // التطبيق الرئيسي (داخل Shell — مع الشريط الجانبي)
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (c, s) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/analytics',
            name: 'analytics',
            builder: (c, s) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: '/competitors',
            name: 'competitors',
            builder: (c, s) => const CompetitorsScreen(),
          ),
          GoRoute(
            path: '/insights',
            name: 'insights',
            builder: (c, s) => const InsightsScreen(),
          ),
          GoRoute(
            path: '/notes',
            name: 'notes',
            builder: (c, s) => const NotesScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (c, s) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );

  // عند أي تغيير في حالة المصادقة → إعادة تقييم التوجيه فوراً
  ref.listen(authStateProvider, (_, __) => router.refresh());

  return router;
});
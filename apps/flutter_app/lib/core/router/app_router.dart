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

/// الـ router يتفاعل مع حالة المصادقة:
/// - بلا جلسة  → يُجبر على /auth
/// - مع جلسة   → يُبعد عن /auth
final goRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final loggedIn = auth.whenOrNull(data: (s) => s.isAuthenticated) ?? false;
      final path = state.matchedLocation;
      final onAuth = path == '/auth';

      if (!loggedIn && !onAuth) return '/auth';
      if (loggedIn && onAuth) return '/dashboard';
      return null;
    },
    routes: [
      // شاشة المصادقة (خارج الـ Shell — بلا sidebar)
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const AuthScreen(),
      ),

      // التطبيق الكامل (داخل الـ Shell)
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(path: '/dashboard', name: 'dashboard',
              builder: (c, s) => const DashboardScreen()),
          GoRoute(path: '/analytics', name: 'analytics',
              builder: (c, s) => const AnalyticsScreen()),
          GoRoute(path: '/competitors', name: 'competitors',
              builder: (c, s) => const CompetitorsScreen()),
          GoRoute(path: '/insights', name: 'insights',
              builder: (c, s) => const InsightsScreen()),
          GoRoute(path: '/notes', name: 'notes',
              builder: (c, s) => const NotesScreen()),
          GoRoute(path: '/settings', name: 'settings',
              builder: (c, s) => const SettingsScreen()),
        ],
      ),
    ],
  );

  // عند أي تغيّر في المصادقة → أعد تقييم التوجيه فوراً.
  ref.listen(authStateProvider, (_, __) => router.refresh());

  return router;
});
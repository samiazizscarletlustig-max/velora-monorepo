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
      final isAuthRoute = path == '/auth''/auth''/dashboard''/auth',
        name: 'auth''/dashboard',
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

  // 
  ref.listen(authStateProvider, (_, __) => router.refresh());

  return router;
});
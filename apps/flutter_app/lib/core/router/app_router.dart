import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/main_scaffold.dart';

// ═══════════════════════════════════════════════════════════
// Placeholder Screens (شاشات مؤقتة - سنستبدلها لاحقاً)
// ═══════════════════════════════════════════════════════════

class PlaceholderScreen extends StatelessWidget {
  final String title;
  
  const PlaceholderScreen({
    super.key, 
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        style: Theme.of(context).textTheme.displayLarge,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Navigator Keys (مفاتيح التنقل)
// ═══════════════════════════════════════════════════════════

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shell',
);

// ═══════════════════════════════════════════════════════════
// App Router (الراوتر الرئيسي)
// ═══════════════════════════════════════════════════════════

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/dashboard',
  
  routes: [
    // ShellRoute = يحافظ على Sidebar موجود دائماً
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return MainScaffold(child: child);
      },
      
      // المسارات داخل الـ Shell
      routes: [
        // ═══ Dashboard ═══
        GoRoute(
          path: '/dashboard',
          name: 'dashboard',
          builder: (context, state) => const PlaceholderScreen(
            title: 'Dashboard',
          ),
        ),
        
        // ═══ Analytics ═══
        GoRoute(
          path: '/analytics',
          name: 'analytics',
          builder: (context, state) => const PlaceholderScreen(
            title: 'Analytics',
          ),
        ),
        
        // ═══ Competitors ═══
        GoRoute(
          path: '/competitors',
          name: 'competitors',
          builder: (context, state) => const PlaceholderScreen(
            title: 'Competitors',
          ),
        ),
        
        // ═══ AI Insights ═══
        GoRoute(
          path: '/insights',
          name: 'insights',
          builder: (context, state) => const PlaceholderScreen(
            title: 'AI Insights',
          ),
        ),
        
        // ═══ Strategic Notes ═══
        GoRoute(
          path: '/notes',
          name: 'notes',
          builder: (context, state) => const PlaceholderScreen(
            title: 'Strategic Notes',
          ),
        ),
        
        // ═══ Settings ═══
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const PlaceholderScreen(
            title: 'Settings',
          ),
        ),
      ],
    ),
  ],
);
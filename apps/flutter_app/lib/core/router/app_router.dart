import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/billing/screens/billing_screen.dart';
import '../../features/ai_chat/screens/ai_chat_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/settings/screens/settings_screen.dart';

// Mock Auth & Onboarding State Providers
final authStateProvider = StateProvider<bool>((ref) => false);
final hasCompletedOnboardingProvider = StateProvider<bool>((ref) => false);

final routerProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(authStateProvider);
  final hasCompletedOnboarding = ref.watch(hasCompletedOnboardingProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      
      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }
      
      if (isAuthenticated && isAuthRoute) {
        if (!hasCompletedOnboarding) {
          return '/onboarding';
        }
        return '/dashboard';
      }
      
      if (isAuthenticated && state.matchedLocation == '/onboarding' && hasCompletedOnboarding) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            title: const Text('Dashboard / لوحة القيادة'),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: Color(0xFF222938)),
            ),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => context.push('/settings'),
                  child: const Text('Settings / الإعدادات'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.push('/chat'),
                  child: const Text('AI Chat / محادثة الذكاء الاصطناعي'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.push('/billing'),
                  child: const Text('Billing / الفوترة'),
                )
              ],
            )
          )
        ),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const AIChatScreen(),
      ),
      GoRoute(
        path: '/billing',
        builder: (context, state) => const BillingScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // ✅ استخدام دالة التهيئة الموجودة في ملفك
  await SupabaseConfig.initialize();

  runApp(
    ProviderScope(
      child: EasyLocalization(
        supportedLocales: const [
          Locale('en'),
          Locale('fr'),
          Locale('es'),
          Locale('pt'),
          Locale('ar'),
          Locale('ja'),
          Locale('ko'),
          Locale('zh'),
        ],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: const VeloraApp(),
      ),
    ),
  );
}

class VeloraApp extends ConsumerWidget {
  const VeloraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Velora',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      debugShowCheckedModeBanner: false,
    );
  }
}
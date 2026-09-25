import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart'; // ✅ يستورد goRouterProvider الآن
import 'core/config/supabase_config.dart';
import 'features/settings/presentation/providers/settings_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // ✅ تهيئة Supabase باستخدام الدالة الاحترافية
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
        useOnlyLangCode: true,           // 🎯 يبحث عن en.json بدلاً من en-US.json
        startLocale: const Locale('en'), // 🎯 فرض الإنجليزية عند البدء
        saveLocale: false,               // 🎯 عدم حفظ اللغة السابقة
        useFallbackTranslations: true,   // 🎯 استخدام fallback إذا لم توجد الترجمة
        child: const VeloraApp(),
      ),
    ),
  );
}

class VeloraApp extends ConsumerWidget {
  const VeloraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ جلب Theme Mode من Provider (ديناميكي)
    final themeModeAsync = ref.watch(themeModeProvider);

    // حساب الـ Theme Mode الحالي (مع fallback إلى Dark)
    final themeMode = themeModeAsync.whenOrNull(
          data: (mode) => mode,
        ) ??
        ThemeMode.dark;

    return MaterialApp.router(
      title: 'Velora',
      debugShowCheckedModeBanner: false,

      // ✅ Theme Mode ديناميكي (يتغير فوراً عند التغيير في Settings)
      themeMode: themeMode,

      // Light Theme
      theme: AppTheme.lightTheme,

      // Dark Theme
      darkTheme: AppTheme.darkTheme,

      // EasyLocalization
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,

      // ✅ Router ديناميكي يتفاعل مع حالة المصادقة
      routerConfig: ref.watch(goRouterProvider),
    );
  }
}
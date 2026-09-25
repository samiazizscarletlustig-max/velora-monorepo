import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart''core/config/supabase_config.dart';
import 'features/settings/presentation/providers/settings_providers.dart''en'),
          Locale('fr'),
          Locale('es'),
          Locale('pt'),
          Locale('ar'),
          Locale('ja'),
          Locale('ko'),
          Locale('zh'),
        ],
        path: 'assets/translations',
        fallbackLocale: const Locale('en''en''Velora',
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
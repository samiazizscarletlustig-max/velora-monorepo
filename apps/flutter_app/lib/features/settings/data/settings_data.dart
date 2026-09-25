import 'package:flutter/material.dart';

// ═══════════════════════════════════════════
// Constants (SharedPreferences Keys)
// ═══════════════════════════════════════════

class SettingsKeys {
  SettingsKeys._(); // Prevent instantiation

  static const String themeMode = 'theme_mode';
  static const String languageCode = 'language_code';
  static const String notificationsEnabled = 'notifications_enabled';
  static const String autoRefreshEnabled = 'auto_refresh_enabled';
  static const String lastSyncTimestamp = 'last_sync_timestamp';
  static const String userId = 'user_id';
}

// ═══════════════════════════════════════════
// Data Classes
// ═══════════════════════════════════════════

/// نموذج اللغة المدعومة
class SupportedLanguage {
  final String code;
  final String name;
  final String flag;
  final Locale locale;

  const SupportedLanguage({
    required this.code,
    required this.name,
    required this.flag,
    required this.locale,
  });

  /// قائمة اللغات المدعومة
  static const List<SupportedLanguage> all = [
    SupportedLanguage(
      code: 'en',
      name: 'English',
      flag: '🇺🇸',
      locale: Locale('en'),
    ),
    SupportedLanguage(
      code: 'fr',
      name: 'Français',
      flag: '🇫🇷',
      locale: Locale('fr'),
    ),
    SupportedLanguage(
      code: 'ar',
      name: 'العربية',
      flag: '🇸🇦',
      locale: Locale('ar'),
    ),
    SupportedLanguage(
      code: 'es',
      name: 'Español',
      flag: '🇪🇸',
      locale: Locale('es'),
    ),
    SupportedLanguage(
      code: 'pt',
      name: 'Português',
      flag: '🇵🇹',
      locale: Locale('pt'),
    ),
    SupportedLanguage(
      code: 'ja',
      name: '日本語',
      flag: '🇯🇵',
      locale: Locale('ja'),
    ),
    SupportedLanguage(
      code: 'ko',
      name: '한국어',
      flag: '🇰🇷',
      locale: Locale('ko'),
    ),
    SupportedLanguage(
      code: 'zh',
      name: '中文',
      flag: '🇨🇳',
      locale: Locale('zh'),
    ),
  ];

  /// البحث عن لغة بالكود
  static SupportedLanguage? fromCode(String code) {
    try {
      return all.firstWhere((lang) => lang.code == code);
    } catch (_) {
      return null;
    }
  }

  /// اللغة الافتراضية
  static const SupportedLanguage defaultLanguage = SupportedLanguage(
    code: 'en',
    name: 'English',
    flag: '🇺🇸',
    locale: Locale('en'),
  );

  @override
  String toString() => '$flag $name';
}

/// نموذج معلومات التطبيق
class AppInfo {
  final String name;
  final String version;
  final String build;
  final String description;
  final String author;
  final String year;
  final String website;
  final String supportEmail;
  final String githubUrl;

  const AppInfo({
    required this.name,
    required this.version,
    required this.build,
    required this.description,
    required this.author,
    required this.year,
    required this.website,
    required this.supportEmail,
    required this.githubUrl,
  });

  /// معلومات التطبيق الثابتة
  static const AppInfo current = AppInfo(
    name: 'Velora',
    version: '1.0.0',
    build: '1',
    description: 'Strategic OS for Competitive Intelligence',
    author: 'Velora Team',
    year: '2026',
    website: 'https://velora.app',
    supportEmail: 'support@velora.app',
    githubUrl: 'https://github.com/velora',
  );

  /// الإصدار الكامل
  String get fullVersion => 'v$version (Build $build)';

  /// حقوق النشر
  String get copyright => '© $year $author';

  @override
  String toString() => '$name $fullVersion';
}

/// نموذج حالة Supabase
class SupabaseStatus {
  final bool isConnected;
  final String message;
  final String? url;
  final DateTime? lastChecked;

  const SupabaseStatus({
    required this.isConnected,
    required this.message,
    this.url,
    this.lastChecked,
  });

  /// حالة متصلة
  factory SupabaseStatus.connected({String? url}) {
    return SupabaseStatus(
      isConnected: true,
      message: 'Connected successfully',
      url: url,
      lastChecked: DateTime.now(),
    );
  }

  /// حالة فشل
  factory SupabaseStatus.failed(String error) {
    return SupabaseStatus(
      isConnected: false,
      message: error,
      url: null,
      lastChecked: DateTime.now(),
    );
  }

  /// لون الحالة (أخضر = متصل، أحمر = فشل)
  Color get statusColor {
    return isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444);
  }

  /// أيقونة الحالة
  IconData get statusIcon {
    return isConnected ? Icons.check_circle : Icons.error;
  }

  /// نص الحالة
  String get statusText {
    return isConnected ? 'Connected' : 'Disconnected';
  }

  @override
  String toString() => 'SupabaseStatus(${isConnected ? "Connected" : "Failed"})';
}

// ═══════════════════════════════════════════
// Theme Options
// ═══════════════════════════════════════════

/// خيارات الثيم المتاحة
class ThemeOption {
  final ThemeMode mode;
  final String label;
  final IconData icon;

  const ThemeOption({
    required this.mode,
    required this.label,
    required this.icon,
  });

  /// قائمة خيارات الثيم
  static const List<ThemeOption> all = [
    ThemeOption(
      mode: ThemeMode.dark,
      label: 'Dark',
      icon: Icons.dark_mode,
    ),
    ThemeOption(
      mode: ThemeMode.light,
      label: 'Light',
      icon: Icons.light_mode,
    ),
    ThemeOption(
      mode: ThemeMode.system,
      label: 'System',
      icon: Icons.settings_brightness,
    ),
  ];

  /// البحث عن خيار بالـ ThemeMode
  static ThemeOption fromMode(ThemeMode mode) {
    return all.firstWhere(
      (option) => option.mode == mode,
      orElse: () => all.first,
    );
  }

  /// الخيار الافتراضي
  static const ThemeOption defaultOption = ThemeOption(
    mode: ThemeMode.dark,
    label: 'Dark',
    icon: Icons.dark_mode,
  );

  @override
  String toString() => label;
}

// ═══════════════════════════════════════════
// Default Values
// ═══════════════════════════════════════════

class SettingsDefaults {
  SettingsDefaults._();

  static const ThemeMode themeMode = ThemeMode.dark;
  static const String languageCode = 'en';
  static const bool notificationsEnabled = true;
  static const bool autoRefreshEnabled = true;
  static const Duration supabaseTimeout = Duration(seconds: 5);
}

// ═══════════════════════════════════════════
// Settings Category (للتنظيم في UI)
// ═══════════════════════════════════════════

enum SettingsCategory {
  appearance(
    label: 'Appearance',
    icon: Icons.palette_outlined,
    description: 'Theme and language settings',
  ),
  notifications(
    label: 'Notifications',
    icon: Icons.notifications_outlined,
    description: 'Alerts and updates',
  ),
  connection(
    label: 'Connection',
    icon: Icons.cloud_outlined,
    description: 'Supabase and data sync',
  ),
  data(
    label: 'Data Management',
    icon: Icons.storage_outlined,
    description: 'Cache and storage',
  ),
  about(
    label: 'About',
    icon: Icons.info_outline,
    description: 'App information',
  );

  final String label;
  final IconData icon;
  final String description;

  const SettingsCategory({
    required this.label,
    required this.icon,
    required this.description,
  });
}
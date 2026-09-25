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
  static const String userId = 'user_id''en',
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
      name: '',
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
      locale: Locale('zh''en',
    name: 'English',
    flag: '🇺🇸',
    locale: Locale('en'),
  );

  @override
  String toString() => '$flag $name''Velora',
    version: '1.0.0',
    build: '1',
    description: 'Strategic OS for Competitive Intelligence',
    author: 'Velora Team',
    year: '2026',
    website: 'https://velora.app',
    supportEmail: 'support@velora.app',
    githubUrl: 'https://github.com/velora''v$version (Build $build)''© $year $author';

  @override
  String toString() => '$name $fullVersion''Connected successfully''Connected' : 'Disconnected';
  }

  @override
  String toString() => 'SupabaseStatus(${isConnected ? "Connected" : "Failed"})''Dark',
      icon: Icons.dark_mode,
    ),
    ThemeOption(
      mode: ThemeMode.light,
      label: 'Light',
      icon: Icons.light_mode,
    ),
    ThemeOption(
      mode: ThemeMode.system,
      label: 'System''Dark',
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
  static const String languageCode = 'en''Appearance',
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
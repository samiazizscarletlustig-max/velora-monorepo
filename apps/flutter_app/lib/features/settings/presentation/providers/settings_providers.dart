import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/settings_repository.dart';
import '../../data/settings_data.dart';

// ═══════════════════════════════════════════
// Repository Provider
// ═══════════════════════════════════════════

/// Provider للـ Repository (Singleton)
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

// ═══════════════════════════════════════════
// Theme Mode Provider
// ═══════════════════════════════════════════

/// Provider لجلب Theme Mode الحالي
final themeModeProvider = FutureProvider<ThemeMode>((ref) async {
  final repository = ref.watch(settingsRepositoryProvider);
  return repository.getThemeMode();
});

/// Provider لتغيير Theme Mode
final setThemeModeProvider = Provider<Future<void> Function(ThemeMode)>((ref) {
  return (ThemeMode mode) async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setThemeMode(mode);
    // Refresh the theme mode provider
    ref.invalidate(themeModeProvider);
  };
});

// ═══════════════════════════════════════════
// Language Provider
// ═══════════════════════════════════════════

/// Provider لجلب اللغة الحالية (كـ SupportedLanguage object)
final currentLanguageProvider = FutureProvider<SupportedLanguage>((ref) async {
  final repository = ref.watch(settingsRepositoryProvider);
  return repository.getCurrentLanguage();
});

/// Provider لجلب كود اللغة الحالية (string فقط)
final languageCodeProvider = FutureProvider<String>((ref) async {
  final repository = ref.watch(settingsRepositoryProvider);
  return repository.getLanguageCode();
});

/// Provider لتغيير اللغة
final setLanguageCodeProvider = Provider<Future<void> Function(String)>((ref) {
  return (String code) async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setLanguageCode(code);
    // Refresh the language providers
    ref.invalidate(languageCodeProvider);
    ref.invalidate(currentLanguageProvider);
  };
});

/// Provider لقائمة اللغات المدعومة (كـ List<SupportedLanguage>)
final supportedLanguagesProvider = Provider<List<SupportedLanguage>>((ref) {
  final repository = ref.watch(settingsRepositoryProvider);
  return repository.getSupportedLanguages();
});

// ═══════════════════════════════════════════
// Notifications Provider
// ═══════════════════════════════════════════

/// Provider لجلب حالة الإشعارات
final notificationsEnabledProvider = FutureProvider<bool>((ref) async {
  final repository = ref.watch(settingsRepositoryProvider);
  return repository.getNotificationsEnabled();
});

/// Provider لتغيير حالة الإشعارات
final setNotificationsEnabledProvider = Provider<Future<void> Function(bool)>((ref) {
  return (bool enabled) async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setNotificationsEnabled(enabled);
    // Refresh the notifications provider
    ref.invalidate(notificationsEnabledProvider);
  };
});

// ═══════════════════════════════════════════
// Auto Refresh Provider
// ═══════════════════════════════════════════

/// Provider لجلب حالة التحديث التلقائي
final autoRefreshEnabledProvider = FutureProvider<bool>((ref) async {
  final repository = ref.watch(settingsRepositoryProvider);
  return repository.getAutoRefreshEnabled();
});

/// Provider لتغيير حالة التحديث التلقائي
final setAutoRefreshEnabledProvider = Provider<Future<void> Function(bool)>((ref) {
  return (bool enabled) async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setAutoRefreshEnabled(enabled);
    // Refresh the auto refresh provider
    ref.invalidate(autoRefreshEnabledProvider);
  };
});

// ═══════════════════════════════════════════
// Supabase Status Provider
// ═══════════════════════════════════════════

/// Provider لفحص حالة الاتصال بـ Supabase (كـ SupabaseStatus object)
final supabaseStatusProvider = FutureProvider<SupabaseStatus>((ref) async {
  final repository = ref.watch(settingsRepositoryProvider);
  return repository.checkSupabaseStatus();
});

// ═══════════════════════════════════════════
// Data Management Provider
// ═══════════════════════════════════════════

/// Provider لمسح الكاش المحلي
final clearCacheProvider = Provider<Future<bool> Function()>((ref) {
  return () async {
    final repository = ref.read(settingsRepositoryProvider);
    final result = await repository.clearLocalCache();

    if (result) {
      // Refresh all providers after clearing cache
      ref.invalidate(themeModeProvider);
      ref.invalidate(languageCodeProvider);
      ref.invalidate(currentLanguageProvider);
      ref.invalidate(notificationsEnabledProvider);
      ref.invalidate(autoRefreshEnabledProvider);
    }

    return result;
  };
});

// ═══════════════════════════════════════════
// App Info Provider
// ═══════════════════════════════════════════

/// Provider لجلب معلومات التطبيق (كـ AppInfo object)
final appInfoProvider = Provider<AppInfo>((ref) {
  final repository = ref.watch(settingsRepositoryProvider);
  return repository.getAppInfo();
});
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'settings_data.dart';

/// Repository لإدارة الإعدادات (محلياً في SharedPreferences)
class SettingsRepository {
  // ═══════════════════════════════════════════
  // Theme Mode
  // ═══════════════════════════════════════════

  /// جلب Theme Mode الحالي
  Future<ThemeMode> getThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(SettingsKeys.themeMode);
      
      if (value == null) return SettingsDefaults.themeMode;
      
      // البحث عن الخيار المناسب
      final option = ThemeOption.all.firstWhere(
        (opt) => opt.mode.toString() == value || opt.label.toLowerCase() == value.toLowerCase(),
        orElse: () => ThemeOption.defaultOption,
      );
      
      return option.mode;
    } catch (e) {
      print('⚠️ Error getting theme mode: $e');
      return SettingsDefaults.themeMode;
    }
  }

  /// حفظ Theme Mode
  Future<void> setThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(SettingsKeys.themeMode, mode.toString());
    } catch (e) {
      print('❌ Error setting theme mode: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════
  // Language
  // ═══════════════════════════════════════════

  /// جلب اللغة الحالية (كـ SupportedLanguage object)
  Future<SupportedLanguage> getCurrentLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(SettingsKeys.languageCode) ?? SettingsDefaults.languageCode;
      return SupportedLanguage.fromCode(code) ?? SupportedLanguage.defaultLanguage;
    } catch (e) {
      print('⚠️ Error getting current language: $e');
      return SupportedLanguage.defaultLanguage;
    }
  }

  /// جلب كود اللغة الحالي (string فقط)
  Future<String> getLanguageCode() async {
    final language = await getCurrentLanguage();
    return language.code;
  }

  /// حفظ اللغة (بالـ code أو بالـ SupportedLanguage object)
  Future<void> setLanguageCode(String code) async {
    try {
      // التحقق من أن اللغة مدعومة
      final language = SupportedLanguage.fromCode(code);
      if (language == null) {
        throw ArgumentError('Unsupported language code: $code');
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(SettingsKeys.languageCode, code);
    } catch (e) {
      print('❌ Error setting language: $e');
      rethrow;
    }
  }

  /// حفظ اللغة (بالـ SupportedLanguage object)
  Future<void> setLanguage(SupportedLanguage language) async {
    await setLanguageCode(language.code);
  }

  /// قائمة اللغات المدعومة
  List<SupportedLanguage> getSupportedLanguages() {
    return SupportedLanguage.all;
  }

  // ═══════════════════════════════════════════
  // Notifications
  // ═══════════════════════════════════════════

  /// جلب حالة الإشعارات
  Future<bool> getNotificationsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(SettingsKeys.notificationsEnabled) ?? SettingsDefaults.notificationsEnabled;
    } catch (e) {
      print('⚠️ Error getting notifications state: $e');
      return SettingsDefaults.notificationsEnabled;
    }
  }

  /// حفظ حالة الإشعارات
  Future<void> setNotificationsEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(SettingsKeys.notificationsEnabled, enabled);
    } catch (e) {
      print('❌ Error setting notifications: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════
  // Auto Refresh
  // ═══════════════════════════════════════════

  /// جلب حالة التحديث التلقائي
  Future<bool> getAutoRefreshEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(SettingsKeys.autoRefreshEnabled) ?? SettingsDefaults.autoRefreshEnabled;
    } catch (e) {
      print('⚠️ Error getting auto refresh state: $e');
      return SettingsDefaults.autoRefreshEnabled;
    }
  }

  /// حفظ حالة التحديث التلقائي
  Future<void> setAutoRefreshEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(SettingsKeys.autoRefreshEnabled, enabled);
    } catch (e) {
      print('❌ Error setting auto refresh: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════
  // Supabase Status
  // ═══════════════════════════════════════════

  /// فحص حالة الاتصال بـ Supabase (يعيد SupabaseStatus object)
  Future<SupabaseStatus> checkSupabaseStatus() async {
    try {
      final client = Supabase.instance.client;
      
      // محاولة جلب سجل واحد للتحقق
      await client
          .from('competitors')
          .select('id')
          .limit(1)
          .timeout(SettingsDefaults.supabaseTimeout);
      
      return SupabaseStatus.connected(url: client.rest.url);
    } catch (e) {
      print('❌ Supabase status check failed: $e');
      return SupabaseStatus.failed(e.toString());
    }
  }

  // ═══════════════════════════════════════════
  // Data Management
  // ═══════════════════════════════════════════

  /// مسح الكاش المحلي (مع الحفاظ على الإعدادات الأساسية)
  Future<bool> clearLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // حفظ الإعدادات الأساسية
      final themeMode = prefs.getString(SettingsKeys.themeMode);
      final languageCode = prefs.getString(SettingsKeys.languageCode);
      
      // مسح كل شيء
      await prefs.clear();
      
      // استعادة الإعدادات الأساسية
      if (themeMode != null) {
        await prefs.setString(SettingsKeys.themeMode, themeMode);
      }
      if (languageCode != null) {
        await prefs.setString(SettingsKeys.languageCode, languageCode);
      }
      
      return true;
    } catch (e) {
      print('❌ Error clearing cache: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════
  // App Info
  // ═══════════════════════════════════════════

  /// جلب معلومات التطبيق (كـ AppInfo object)
  AppInfo getAppInfo() {
    return AppInfo.current;
  }

  // ═══════════════════════════════════════════
  // Last Sync Timestamp (Bonus feature)
  // ═══════════════════════════════════════════

  /// جلب آخر وقت مزامنة
  Future<DateTime?> getLastSyncTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(SettingsKeys.lastSyncTimestamp);
      if (timestamp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      return null;
    }
  }

  /// تحديث آخر وقت مزامنة
  Future<void> updateLastSyncTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        SettingsKeys.lastSyncTimestamp,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      print('⚠️ Error updating sync timestamp: $e');
    }
  }
}
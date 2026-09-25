import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'settings_data.dart''⚠️ Error getting theme mode: $e');
      return SettingsDefaults.themeMode;
    }
  }

  /// Save Theme Mode
  Future<void> setThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(SettingsKeys.themeMode, mode.toString());
    } catch (e) {
      print('❌ Error setting theme mode: $e''⚠️ Error getting current language: $e''Unsupported language code: $code');
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(SettingsKeys.languageCode, code);
    } catch (e) {
      print('❌ Error setting language: $e''⚠️ Error getting notifications state: $e''❌ Error setting notifications: $e''⚠️ Error getting auto refresh state: $e''❌ Error setting auto refresh: $e''competitors')
          .select('id')
          .limit(1)
          .timeout(SettingsDefaults.supabaseTimeout);
      
      return SupabaseStatus.connected(url: client.rest.url);
    } catch (e) {
      print('❌ Supabase status check failed: $e''❌ Error clearing cache: $e''⚠️ Error updating sync timestamp: $e');
    }
  }
}
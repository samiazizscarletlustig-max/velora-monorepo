import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/localization/localization_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = ref.watch(l10nProvider);
    final currentLang = ref.watch(languageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n['settings']!),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildSectionHeader(context, l10n['profile']!),
              _buildProfileCard(context, isDark, l10n),
              const SizedBox(height: 32),
              
              _buildSectionHeader(context, l10n['appearance']!),
              _buildGlassCard(
                context,
                isDark,
                child: Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      title: Text(l10n['system']!),
                      value: ThemeMode.system,
                      groupValue: themeMode,
                      onChanged: (mode) => ref.read(themeProvider.notifier).setTheme(mode!),
                    ),
                    RadioListTile<ThemeMode>(
                      title: Text(l10n['light']!),
                      value: ThemeMode.light,
                      groupValue: themeMode,
                      onChanged: (mode) => ref.read(themeProvider.notifier).setTheme(mode!),
                    ),
                    RadioListTile<ThemeMode>(
                      title: Text(l10n['dark']!),
                      value: ThemeMode.dark,
                      groupValue: themeMode,
                      onChanged: (mode) => ref.read(themeProvider.notifier).setTheme(mode!),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              _buildSectionHeader(context, l10n['language']!),
              _buildGlassCard(
                context,
                isDark,
                child: Column(
                  children: [
                    RadioListTile<AppLanguage>(
                      title: Text(l10n['lang_en']!),
                      value: AppLanguage.english,
                      groupValue: currentLang,
                      onChanged: (lang) => ref.read(languageProvider.notifier).state = lang!,
                    ),
                    RadioListTile<AppLanguage>(
                      title: Text(l10n['lang_fr']!),
                      value: AppLanguage.french,
                      groupValue: currentLang,
                      onChanged: (lang) => ref.read(languageProvider.notifier).state = lang!,
                    ),
                    RadioListTile<AppLanguage>(
                      title: Text(l10n['lang_es']!),
                      value: AppLanguage.spanish,
                      groupValue: currentLang,
                      onChanged: (lang) => ref.read(languageProvider.notifier).state = lang!,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              _buildSectionHeader(context, l10n['notifications']!),
              _buildGlassCard(
                context,
                isDark,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(l10n['email_alerts']!),
                      subtitle: Text(l10n['email_alerts_sub']!, style: const TextStyle(fontSize: 12)),
                      value: true,
                      onChanged: (val) {},
                    ),
                    SwitchListTile(
                      title: Text(l10n['push_notifications']!),
                      subtitle: Text(l10n['push_notifications_sub']!, style: const TextStyle(fontSize: 12)),
                      value: false,
                      onChanged: (val) {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              _buildSectionHeader(context, l10n['danger_zone']!, color: Colors.redAccent),
              _buildGlassCard(
                context,
                isDark,
                child: ListTile(
                  title: Text(l10n['delete_workspace']!, style: const TextStyle(color: Colors.redAccent)),
                  subtitle: Text(l10n['delete_workspace_sub']!),
                  trailing: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(l10n['delete_confirm_title']!),
                          content: Text(l10n['delete_confirm_msg']!),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n['cancel']!)),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                              onPressed: () {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n['workspace_deleted']!)));
                              },
                              child: Text(l10n['delete_btn']!),
                            )
                          ],
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.1),
                      foregroundColor: Colors.redAccent,
                      elevation: 0,
                    ),
                    child: Text(l10n['delete_btn']!),
                  ),
                ),
              ),
              const SizedBox(height: 64),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, {Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 16),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: color ?? (isDark ? Colors.white54 : Colors.black54),
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, bool isDark, Map<String, String> l10n) {
    return _buildGlassCard(
      context,
      isDark,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              child: Text(
                'JD',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('John Doe', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('john.doe@example.com', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                side: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
              ),
              child: Text(l10n['edit']!, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () {
                context.go('/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
                foregroundColor: isDark ? Colors.white : Colors.black,
                elevation: 0,
              ),
              child: Text(l10n['logout']!),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard(BuildContext context, bool isDark, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B26).withOpacity(0.5) : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: child,
        ),
      ),
    );
  }
}

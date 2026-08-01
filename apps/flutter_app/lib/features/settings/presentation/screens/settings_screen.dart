import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/widgets/velora_card.dart';
import '../providers/settings_providers.dart';
import '../../data/settings_data.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeModeAsync = ref.watch(themeModeProvider);
    final languageAsync = ref.watch(languageCodeProvider);
    final notificationsAsync = ref.watch(notificationsEnabledProvider);
    final autoRefreshAsync = ref.watch(autoRefreshEnabledProvider);
    final supabaseStatusAsync = ref.watch(supabaseStatusProvider);
    final appInfo = ref.watch(appInfoProvider);
    final supportedLanguages = ref.watch(supportedLanguagesProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ═══ Header ═══
            Text(
              'settings.title'.tr(),
              style: theme.textTheme.displayLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'settings.subtitle'.tr(),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 32),

            // ═══ Appearance Section ═══
            _SectionHeader(
              icon: Icons.palette_outlined,
              title: 'settings.appearance'.tr(),
              subtitle: 'settings.appearance_subtitle'.tr(),
            ),
            const SizedBox(height: 12),
            VeloraCard(
              child: Column(
                children: [
                  // Theme Mode
                  themeModeAsync.when(
                    data: (mode) => _ThemeSelector(
                      currentMode: mode,
                      onChanged: (newMode) async {
                        await ref.read(setThemeModeProvider)(newMode);
                      },
                    ),
                    loading: () => const _SettingsLoadingTile(),
                    error: (e, _) => _ErrorTile(error: e.toString()),
                  ),
                  const Divider(height: 1),
                  // Language
                  languageAsync.when(
                    data: (code) => _LanguageSelector(
                      currentCode: code,
                      languages: supportedLanguages,
                      onChanged: (newCode) async {
                        await ref.read(setLanguageCodeProvider)(newCode);
                        // Apply locale change immediately
                        if (context.mounted) {
                          final language = supportedLanguages.firstWhere(
                            (l) => l.code == newCode,
                            orElse: () => supportedLanguages.first,
                          );
                          await context.setLocale(language.locale);
                        }
                      },
                    ),
                    loading: () => const _SettingsLoadingTile(),
                    error: (e, _) => _ErrorTile(error: e.toString()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ═══ Notifications Section ═══
            _SectionHeader(
              icon: Icons.notifications_outlined,
              title: 'settings.notifications'.tr(),
              subtitle: 'settings.notifications_subtitle'.tr(),
            ),
            const SizedBox(height: 12),
            VeloraCard(
              child: Column(
                children: [
                  notificationsAsync.when(
                    data: (enabled) => _ToggleTile(
                      icon: Icons.notifications_active_outlined,
                      title: 'settings.enable_notifications'.tr(),
                      subtitle: 'settings.enable_notifications_desc'.tr(),
                      value: enabled,
                      onChanged: (value) async {
                        await ref.read(setNotificationsEnabledProvider)(value);
                      },
                    ),
                    loading: () => const _SettingsLoadingTile(),
                    error: (e, _) => _ErrorTile(error: e.toString()),
                  ),
                  const Divider(height: 1),
                  autoRefreshAsync.when(
                    data: (enabled) => _ToggleTile(
                      icon: Icons.refresh,
                      title: 'settings.auto_refresh'.tr(),
                      subtitle: 'settings.auto_refresh_desc'.tr(),
                      value: enabled,
                      onChanged: (value) async {
                        await ref.read(setAutoRefreshEnabledProvider)(value);
                      },
                    ),
                    loading: () => const _SettingsLoadingTile(),
                    error: (e, _) => _ErrorTile(error: e.toString()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ═══ Connection Section ═══
            _SectionHeader(
              icon: Icons.cloud_outlined,
              title: 'settings.connection'.tr(),
              subtitle: 'settings.connection_subtitle'.tr(),
            ),
            const SizedBox(height: 12),
            supabaseStatusAsync.when(
              data: (status) => VeloraCard(
                child: _SupabaseStatusTile(status: status),
              ),
              loading: () => VeloraCard(
                child: const _SettingsLoadingTile(),
              ),
              error: (e, _) => VeloraCard(
                child: _ErrorTile(error: e.toString()),
              ),
            ),
            const SizedBox(height: 24),

            // ═══ Data Management Section ═══
            _SectionHeader(
              icon: Icons.storage_outlined,
              title: 'settings.data_management'.tr(),
              subtitle: 'settings.data_management_subtitle'.tr(),
            ),
            const SizedBox(height: 12),
            VeloraCard(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.cleaning_services_outlined,
                    color: Color(0xFFEF4444),
                    size: 20,
                  ),
                ),
                title: Text(
                  'settings.clear_cache'.tr(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'settings.clear_cache_desc'.tr(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showClearCacheDialog(context, ref),
              ),
            ),
            const SizedBox(height: 24),

            // ═══ About Section ═══
            _SectionHeader(
              icon: Icons.info_outline,
              title: 'settings.about'.tr(),
              subtitle: 'settings.about_subtitle'.tr(),
            ),
            const SizedBox(height: 12),
            VeloraCard(
              child: Column(
                children: [
                  _AboutTile(
                    icon: Icons.apps,
                    label: 'settings.app_name'.tr(),
                    value: appInfo.name,
                  ),
                  const Divider(height: 1),
                  _AboutTile(
                    icon: Icons.tag,
                    label: 'settings.version'.tr(),
                    value: appInfo.fullVersion,
                  ),
                  const Divider(height: 1),
                  _AboutTile(
                    icon: Icons.description_outlined,
                    label: 'settings.description'.tr(),
                    value: appInfo.description,
                  ),
                  const Divider(height: 1),
                  _AboutTile(
                    icon: Icons.person_outline,
                    label: 'settings.author'.tr(),
                    value: appInfo.author,
                  ),
                  const Divider(height: 1),
                  _AboutLinkTile(
                    icon: Icons.language,
                    label: 'settings.website'.tr(),
                    url: appInfo.website,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ═══ Footer ═══
            Center(
              child: Text(
                appInfo.copyright,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('settings.clear_cache_title'.tr()),
        content: Text('settings.clear_cache_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final result = await ref.read(clearCacheProvider)();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result
                          ? 'settings.cache_cleared'.tr()
                          : 'settings.cache_clear_failed'.tr(),
                    ),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Section Header Widget
// ═══════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF4F46E5).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF4F46E5), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════
// Theme Selector Widget
// ═══════════════════════════════════════════

class _ThemeSelector extends StatelessWidget {
  final ThemeMode currentMode;
  final Function(ThemeMode) onChanged;

  const _ThemeSelector({
    required this.currentMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    IconData icon;
    String label;

    switch (currentMode) {
      case ThemeMode.light:
        icon = Icons.light_mode;
        label = 'settings.theme_light'.tr();
        break;
      case ThemeMode.dark:
        icon = Icons.dark_mode;
        label = 'settings.theme_dark'.tr();
        break;
      case ThemeMode.system:
        icon = Icons.settings_brightness;
        label = 'settings.theme_system'.tr();
        break;
    }

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF4F46E5).withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF4F46E5), size: 20),
      ),
      title: Text(
        'settings.theme'.tr(),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.secondary,
        ),
      ),
      trailing: PopupMenuButton<ThemeMode>(
        initialValue: currentMode,
        onSelected: onChanged,
        itemBuilder: (context) => [
          PopupMenuItem(
            value: ThemeMode.dark,
            child: Row(
              children: [
                const Icon(Icons.dark_mode, size: 18),
                const SizedBox(width: 8),
                Text('settings.theme_dark'.tr()),
              ],
            ),
          ),
          PopupMenuItem(
            value: ThemeMode.light,
            child: Row(
              children: [
                const Icon(Icons.light_mode, size: 18),
                const SizedBox(width: 8),
                Text('settings.theme_light'.tr()),
              ],
            ),
          ),
          PopupMenuItem(
            value: ThemeMode.system,
            child: Row(
              children: [
                const Icon(Icons.settings_brightness, size: 18),
                const SizedBox(width: 8),
                Text('settings.theme_system'.tr()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Language Selector Widget
// ═══════════════════════════════════════════

class _LanguageSelector extends StatelessWidget {
  final String currentCode;
  final List<SupportedLanguage> languages;
  final Function(String) onChanged;

  const _LanguageSelector({
    required this.currentCode,
    required this.languages,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentLang = languages.firstWhere(
      (l) => l.code == currentCode,
      orElse: () => languages.first,
    );

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          currentLang.flag,
          style: const TextStyle(fontSize: 20),
        ),
      ),
      title: Text(
        'settings.language'.tr(),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        currentLang.name,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.secondary,
        ),
      ),
      trailing: PopupMenuButton<String>(
        initialValue: currentCode,
        onSelected: onChanged,
        itemBuilder: (context) => languages.map((lang) {
          return PopupMenuItem(
            value: lang.code,
            child: Row(
              children: [
                Text(lang.flag, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(lang.name),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Toggle Tile Widget
// ═══════════════════════════════════════════

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Function(bool) onChanged;

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFFF59E0B), size: 20),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.secondary,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}

// ═══════════════════════════════════════════
// Supabase Status Tile Widget
// ═══════════════════════════════════════════

class _SupabaseStatusTile extends StatelessWidget {
  final SupabaseStatus status;

  const _SupabaseStatusTile({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: status.statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              status.statusIcon,
              color: status.statusColor,
              size: 20,
            ),
          ),
          title: Text(
            'settings.supabase_status'.tr(),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            status.statusText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: status.statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (status.url != null && status.isConnected)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.link,
                  size: 14,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status.url!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════
// About Tile Widget
// ═══════════════════════════════════════════

class _AboutTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AboutTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.secondary),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutLinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String url;

  const _AboutLinkTile({
    required this.icon,
    required this.label,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF4F46E5)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF4F46E5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.open_in_new,
              size: 16,
              color: Color(0xFF4F46E5),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Loading & Error Widgets
// ═══════════════════════════════════════════

class _SettingsLoadingTile extends StatelessWidget {
  const _SettingsLoadingTile();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  final String error;

  const _ErrorTile({required this.error});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Error: $error',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFEF4444),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
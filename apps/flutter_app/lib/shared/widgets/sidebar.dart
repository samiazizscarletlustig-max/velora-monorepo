import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String currentPath = GoRouterState.of(context).uri.path;

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          right: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: theme.colorScheme.onSurface, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Velora',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              children: [
                _SidebarItem(
                  icon: Icons.dashboard_outlined,
                  label: 'nav.dashboard'.tr(),
                  path: '/dashboard',
                  isSelected: currentPath == '/dashboard',
                ),
                _SidebarItem(
                  icon: Icons.bar_chart_outlined,
                  label: 'nav.analytics'.tr(),
                  path: '/analytics',
                  isSelected: currentPath == '/analytics',
                ),
                _SidebarItem(
                  icon: Icons.storefront_outlined,
                  label: 'nav.competitors'.tr(),
                  path: '/competitors',
                  isSelected: currentPath == '/competitors',
                ),
                _SidebarItem(
                  icon: Icons.lightbulb_outline,
                  label: 'nav.insights'.tr(),
                  path: '/insights',
                  isSelected: currentPath == '/insights',
                ),
                _SidebarItem(
                  icon: Icons.note_alt_outlined,
                  label: 'nav.notes'.tr(),
                  path: '/notes',
                  isSelected: currentPath == '/notes',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: _SidebarItem(
              icon: Icons.settings_outlined,
              label: 'nav.settings'.tr(),
              path: '/settings',
              isSelected: currentPath == '/settings',
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String path;
  final bool isSelected;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.path,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isSelected ? theme.colorScheme.onSurface : theme.colorScheme.secondary;
    final bgColor = isSelected ? theme.colorScheme.surfaceContainerHighest : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: InkWell(
        onTap: () {
          if (!isSelected) {
            context.go(path);
          }
          if (Scaffold.of(context).hasDrawer && Scaffold.of(context).isDrawerOpen) {
            Navigator.of(context).pop();
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
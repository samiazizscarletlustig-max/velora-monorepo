import 'package:flutter/material.dart';

class VeloraSideNav extends StatelessWidget {
  const VeloraSideNav({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.8),
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Row(
              children: [
                Icon(Icons.insights, color: Color(0xFF6366F1), size: 32),
                SizedBox(width: 12),
                Text(
                  "Velora",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          _NavItem(icon: Icons.dashboard, title: "Dashboard", isActive: true),
          _NavItem(icon: Icons.storefront, title: "Competitors"),
          _NavItem(icon: Icons.inventory_2, title: "Products"),
          _NavItem(icon: Icons.auto_graph, title: "Reports"),
          const Spacer(),
          _NavItem(icon: Icons.settings, title: "Settings"),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isActive;

  const _NavItem({
    required this.icon,
    required this.title,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF6366F1).withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isActive ? const Color(0xFF6366F1) : Colors.grey,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () {},
      ),
    );
  }
}

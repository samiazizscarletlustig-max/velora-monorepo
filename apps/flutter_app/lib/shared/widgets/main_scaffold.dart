import 'package:flutter/material.dart';
import 'sidebar.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      body: Row(
        children: [
          if (isDesktop) const Sidebar(),
          Expanded(
            child: Column(
              children: [
                if (!isDesktop) 
                  AppBar(
                    title: const Text('Velora'),
                    leading: Builder(
                      builder: (context) => IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                  ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
      drawer: isDesktop ? null : const Drawer(child: Sidebar()),
    );
  }
}
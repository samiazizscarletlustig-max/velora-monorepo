import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ ضروري لـ AutofillHints
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/competitors_providers.dart';
import '../../auth/providers/auth_providers.dart';

class CompetitorsScreen extends ConsumerWidget {
  const CompetitorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final competitorsAsync = ref.watch(competitorsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Competitors'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context, ref),
            tooltip: 'Add Competitor',
          ),
        ],
      ),
      body: competitorsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (competitors) {
          if (competitors.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store_mall_directory_outlined, size: 64, color: Colors.grey[600]),
                  const SizedBox(height: 16),
                  Text('No competitors yet', style: TextStyle(color: Colors.grey[600], fontSize: 18)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showAddDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Your First Competitor'),
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: competitors.length,
            itemBuilder: (context, index) {
              final comp = competitors[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(child: Text(comp.name[0].toUpperCase())),
                  title: Text(comp.name),
                  subtitle: Text(comp.website ?? 'No website'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      await ref.read(competitorsRepositoryProvider).deleteCompetitor(comp.id);
                      ref.invalidate(competitorsProvider);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final websiteCtrl = TextEditingController();
    final shopifyCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Competitor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ الحل القاطع: منع المعاينة التلقائية (Ghost Text) نهائياً
              TextField(
                controller: nameCtrl, 
                decoration: const InputDecoration(labelText: 'Name *'),
                keyboardType: TextInputType.name,
                autofillHints: const [AutofillHints.newUsername], // يخبر المتصفح أن هذا اسم جديد
                enableSuggestions: false,
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: websiteCtrl, 
                decoration: const InputDecoration(labelText: 'Website'),
                autofillHints: const [],
                keyboardType: TextInputType.url,
                enableSuggestions: false,
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: shopifyCtrl, 
                decoration: const InputDecoration(labelText: 'Shopify Store URL'),
                autofillHints: const [],
                keyboardType: TextInputType.url,
                enableSuggestions: false,
                autocorrect: false,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              
              // ✅ جلب معرف المستخدم الحالي من Auth Provider
              final authState = ref.read(authStateProvider).value;
              final userId = authState?.user?.id;
              
              if (userId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please sign in first')),
                );
                return;
              }
              
              // ✅ تمرير userId للإضافة
              await ref.read(competitorsRepositoryProvider).addCompetitor(
                name: nameCtrl.text.trim(),
                website: websiteCtrl.text.trim(),
                shopifyStore: shopifyCtrl.text.trim(),
                userId: userId,
              );
              
              ref.invalidate(competitorsProvider);
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
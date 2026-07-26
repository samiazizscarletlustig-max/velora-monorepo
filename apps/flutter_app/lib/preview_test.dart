import 'package:flutter/material.dart';

class SmartNotesPreview extends StatelessWidget {
  const SmartNotesPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Row(
        children: [
          _buildSidebar(context),
          Expanded(child: _buildMainContent(context)),
          _buildRightSidebar(context),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 260,
      color: const Color(0xFF0A0E1A),
      border: const Border(right: BorderSide(color: Color(0xFF222938))),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.dashboard_customize, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              const Text('Velora', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 48),
          const _NavItem(icon: Icons.edit_note, label: 'Smart Notes\nملاحظات ذكية', isSelected: true),
          const _NavItem(icon: Icons.analytics, label: 'Analysis Hub\nمركز التحليل', isSelected: false),
          const _NavItem(icon: Icons.account_tree, label: 'Strategy Canvas\nلوحة الاستراتيجية', isSelected: false),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context, 'Q4 Competitor Response / رد المنافسين للربع الرابع'),
        const Divider(height: 1, color: Color(0xFF222938)),
        _buildToolbar(context),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Q4 Pricing Strategy\nاستراتيجية التسعير للربع الرابع',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, height: 1.3),
                ),
                const SizedBox(height: 32),
                _buildCallout(context),
                const SizedBox(height: 24),
                const Text(
                  'We observed a 12% price drop from Noon on key electronic SKUs ahead of White Friday. To counter this without sacrificing margins, we should bundle high-margin accessories with flagship devices.\n\nلاحظنا انخفاضاً بنسبة 12٪ في أسعار نون على منتجات الإلكترونيات الرئيسية قبل الجمعة البيضاء. ولمواجهة ذلك دون التضحية بهوامش الربح، يجب علينا تقديم حزم ملحقات ذات هوامش ربح عالية مع الأجهزة الرئيسية.',
                  style: TextStyle(fontSize: 16, height: 1.8, color: Colors.white70),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                      ),
                      child: Text(
                        '[[Noon Price Tracker]]',
                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, String title) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          const Text('Workspace / Strategy / ', style: TextStyle(color: Colors.white54)),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.share, size: 16),
            label: const Text('Share'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF161B26), foregroundColor: Colors.white),
          )
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(color: Color(0xFF0A0E1A), border: Border(bottom: BorderSide(color: Color(0xFF222938)))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFF161B26), borderRadius: BorderRadius.circular(6)),
            child: const Row(children: [Text('Text', style: TextStyle(fontSize: 14)), SizedBox(width: 8), Icon(Icons.arrow_drop_down, size: 16)]),
          ),
          Container(width: 1, height: 24, color: const Color(0xFF222938), margin: const EdgeInsets.symmetric(horizontal: 16)),
          const Icon(Icons.format_bold, color: Colors.white70, size: 20),
          const SizedBox(width: 16),
          const Icon(Icons.format_italic, color: Colors.white70, size: 20),
        ],
      ),
    );
  }

  Widget _buildCallout(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 20),
          ),
          const SizedBox(width: 16),
          const Expanded(child: Text('AI Insight: Focus on Smart Home category where Amazon SA is showing inventory shortages.', style: TextStyle(color: Colors.amber, height: 1.5))),
        ],
      ),
    );
  }

  Widget _buildRightSidebar(BuildContext context) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Color(0xFF131A2B),
        border: Border(left: BorderSide(color: Color(0xFF222938))),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tags', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTag(context, '#strategy'),
              _buildTag(context, '#pricing'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTag(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF222938),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;

  const _NavItem({required this.icon, required this.label, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? Theme.of(context).colorScheme.primary : Colors.white70;
    final bg = isSelected ? color.withOpacity(0.1) : Colors.transparent;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: isSelected ? color : Colors.transparent, width: 3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: TextStyle(color: color, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13, height: 1.4))),
        ],
      ),
    );
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/glass_container.dart';
import '../../shared/side_nav.dart';
import '../../shared/stat_card.dart';
import '../../shared/smooth_line_chart.dart';
import '../ai_chat/ai_chat_panel.dart';
import 'providers/dashboard_provider.dart';

class VeloraDashboard extends ConsumerWidget {
  const VeloraDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // الاستماع لحالة فتح وإغلاق الشات
    final isChatOpen = ref.watch(aiChatOpenProvider);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Background Gradients (SaaS Vibe)
          Positioned(
            top: -150,
            left: -150,
            child: _buildGlow(const Color(0xFF6366F1).withOpacity(0.15), 400),
          ),
          Positioned(
            bottom: -200,
            right: -100,
            child: _buildGlow(const Color(0xFF10B981).withOpacity(0.1), 500),
          ),

          // 2. Main Layout
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 800;
                return Row(
                  children: [
                    if (isDesktop) const VeloraSideNav(),
                    Expanded(
                      child: CustomScrollView(
                        slivers: [
                          _buildAppBar(isDesktop),
                          SliverPadding(
                            padding: const EdgeInsets.all(24.0),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                _buildStatsRow(isDesktop),
                                const SizedBox(height: 24),
                                if (isDesktop)
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 2, child: _buildPriceChartSection(ref)),
                                      const SizedBox(width: 24),
                                      Expanded(flex: 1, child: _buildInsightsFeed(ref)),
                                    ],
                                  )
                                else ...[
                                  _buildPriceChartSection(ref),
                                  const SizedBox(height: 24),
                                  _buildInsightsFeed(ref),
                                ],
                              ]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // 3. AI Chat Overlay
          if (isChatOpen)
            const Positioned(
              right: 24,
              bottom: 80,
              width: 350,
              height: 500,
              child: AIChatPanel(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ref.read(aiChatOpenProvider.notifier).update((state) => !state);
        },
        backgroundColor: const Color(0xFF6366F1),
        icon: Icon(isChatOpen ? Icons.close : Icons.auto_awesome),
        label: Text(isChatOpen ? "Close AI" : "Ask Velora AI"),
      ),
    );
  }

  Widget _buildGlow(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  SliverAppBar _buildAppBar(bool isDesktop) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      leading: !isDesktop ? IconButton(icon: const Icon(Icons.menu), onPressed: () {}) : null,
      title: const Text(
        "Intelligence Dashboard",
        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
      actions: [
        GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          borderRadius: 20,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              const Text("Delta Active", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(width: 24),
      ],
    );
  }

  Widget _buildStatsRow(bool isDesktop) {
    return Flex(
      direction: isDesktop ? Axis.horizontal : Axis.vertical,
      children: [
        Expanded(flex: isDesktop ? 1 : 0, child: const StatCard(title: "Monitored Products", value: "1,204", trend: "+12%", isPositive: true)),
        SizedBox(width: isDesktop ? 16 : 0, height: !isDesktop ? 16 : 0),
        Expanded(flex: isDesktop ? 1 : 0, child: const StatCard(title: "Price Drops Detected", value: "47", trend: "-5%", isPositive: false)),
        SizedBox(width: isDesktop ? 16 : 0, height: !isDesktop ? 16 : 0),
        Expanded(flex: isDesktop ? 1 : 0, child: const StatCard(title: "Actionable Insights", value: "12", trend: "Today", isPositive: true)),
      ],
    );
  }

  Widget _buildPriceChartSection(WidgetRef ref) {
    final priceDataAsync = ref.watch(priceHistoryProvider);
    
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Competitor Price Volatility (30 Days)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            width: double.infinity,
            child: priceDataAsync.when(
              data: (data) => CustomPaint(
                painter: SmoothLineChartPainter(data: data),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error loading chart: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsFeed(WidgetRef ref) {
    final insightsAsync = ref.watch(insightsProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Velora AI Insights", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        insightsAsync.when(
          data: (insights) {
             if (insights.isEmpty) {
                 return const Center(child: Text("No insights available."));
             }
             return Column(
               children: insights.map((insight) => Padding(
                 padding: const EdgeInsets.only(bottom: 16),
                 child: AIInsightCard(insight: insight),
               )).toList(),
             );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error loading insights: $err')),
        ),
      ],
    );
  }
}

class AIInsightCard extends StatelessWidget {
  final Map<String, dynamic> insight;

  const AIInsightCard({super.key, required this.insight});

  @override
  Widget build(BuildContext context) {
    final severityStr = insight['severity'] ?? 'low';
    final severityColor = severityStr == 'high'
        ? Colors.redAccent
        : severityStr == 'medium'
            ? Colors.orangeAccent
            : Colors.blueAccent;

    return GlassContainer(
      border: Border.all(color: severityColor.withOpacity(0.3), width: 1),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: severityColor, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(insight['insight_title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            ],
          ),
          const SizedBox(height: 12),
          Text(insight['insight_details'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: severityColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, color: severityColor, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(insight['actionable_advice'] ?? '', style: TextStyle(color: severityColor.withOpacity(0.9), fontSize: 13, height: 1.4))),
              ],
            ),
          )
        ],
      ),
    );
  }
}

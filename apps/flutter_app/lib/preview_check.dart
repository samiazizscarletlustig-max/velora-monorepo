import 'dart:ui';
import 'package:flutter/material.dart';

void main() {
  runApp(const VeloraPreviewApp());
}

class VeloraPreviewApp extends StatelessWidget {
  const VeloraPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Velora AI Dashboard - Preview',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0F19), // Deep FinTech Dark
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1), // Indigo
          secondary: Color(0xFF10B981), // Emerald
          surface: Color(0xFF1E293B),
          background: Color(0xFF0B0F19),
        ),
        fontFamily: 'Segoe UI', // Fallback premium font
      ),
      home: const VeloraDashboardPreview(),
    );
  }
}

// ==========================================
// MOCK DATA (For Visual Check Only)
// ==========================================
final List<Map<String, dynamic>> mockInsights = [
  {
    "insight_title": "Aggressive Price Drop Detected",
    "insight_details": "Competitor 'TechNova' reduced the price of 'Wireless Earbuds Pro' by 18% in the last 2 hours.",
    "actionable_advice": "Consider running a 24-hour flash sale or highlighting your superior warranty to counter this drop.",
    "severity": "high",
  },
  {
    "insight_title": "Out of Stock Opportunity",
    "insight_details": "Primary competitor is currently out of stock for 'Mechanical Keyboard V2'.",
    "actionable_advice": "Increase ad spend on this keyword by 20% to capture migrating customers.",
    "severity": "medium",
  },
  {
    "insight_title": "Stagnant Pricing",
    "insight_details": "No significant price changes in the 'Smart Home' category across top 3 competitors this week.",
    "actionable_advice": "Maintain current pricing margins. Focus on SEO optimizations.",
    "severity": "low",
  }
];

final List<double> mockPriceData = [120, 118, 118, 125, 122, 115, 105, 100, 95];

// ==========================================
// MAIN DASHBOARD SCREEN
// ==========================================
class VeloraDashboardPreview extends StatefulWidget {
  const VeloraDashboardPreview({super.key});

  @override
  State<VeloraDashboardPreview> createState() => _VeloraDashboardPreviewState();
}

class _VeloraDashboardPreviewState extends State<VeloraDashboardPreview> {
  bool isChatOpen = false;

  @override
  Widget build(BuildContext context) {
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
                                      Expanded(flex: 2, child: _buildPriceChartSection()),
                                      const SizedBox(width: 24),
                                      Expanded(flex: 1, child: _buildInsightsFeed()),
                                    ],
                                  )
                                else ...[
                                  _buildPriceChartSection(),
                                  const SizedBox(height: 24),
                                  _buildInsightsFeed(),
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
            Positioned(
              right: 24,
              bottom: 80,
              width: 350,
              height: 500,
              child: const AIChatPanel(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            isChatOpen = !isChatOpen;
          });
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

  Widget _buildPriceChartSection() {
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
            child: CustomPaint(
              painter: SmoothLineChartPainter(data: mockPriceData),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsFeed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Velora AI Insights", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ...mockInsights.map((insight) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: AIInsightCard(insight: insight),
            )),
      ],
    );
  }
}

// ==========================================
// COMPONENTS
// ==========================================

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
                Text("Velora", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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

  const _NavItem({required this.icon, required this.title, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF6366F1).withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: isActive ? const Color(0xFF6366F1) : Colors.grey),
        title: Text(title, style: TextStyle(color: isActive ? Colors.white : Colors.grey, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
        onTap: () {},
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String trend;
  final bool isPositive;

  const StatCard({super.key, required this.title, required this.value, required this.trend, required this.isPositive});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive ? Colors.greenAccent.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(trend, style: TextStyle(color: isPositive ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
              )
            ],
          )
        ],
      ),
    );
  }
}

class AIInsightCard extends StatelessWidget {
  final Map<String, dynamic> insight;

  const AIInsightCard({super.key, required this.insight});

  @override
  Widget build(BuildContext context) {
    final severityColor = insight['severity'] == 'high'
        ? Colors.redAccent
        : insight['severity'] == 'medium'
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
              Expanded(child: Text(insight['insight_title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            ],
          ),
          const SizedBox(height: 12),
          Text(insight['insight_details'], style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5)),
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
                Expanded(child: Text(insight['actionable_advice'], style: TextStyle(color: severityColor.withOpacity(0.9), fontSize: 13, height: 1.4))),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class AIChatPanel extends StatelessWidget {
  const AIChatPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3), width: 1.5),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Color(0xFF6366F1)),
                SizedBox(width: 8),
                Text("Velora Intelligence", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildChatBubble("Can you analyze Shopify's recent pricing trend?", true),
                const SizedBox(height: 12),
                _buildChatBubble("Based on the data, they have lowered prices by an average of 4% across electronics.", false),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Ask about competitors...",
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                filled: true,
                fillColor: Colors.black.withOpacity(0.3),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                suffixIcon: const Icon(Icons.send, color: Color(0xFF6366F1), size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF6366F1) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
            bottomLeft: !isUser ? const Radius.circular(0) : const Radius.circular(16),
          ),
        ),
        child: Text(text, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}

// ==========================================
// UTILITY WIDGETS
// ==========================================

class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final BoxBorder? border;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 16,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ?? Border.all(color: Colors.white.withOpacity(0.05), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

class SmoothLineChartPainter extends CustomPainter {
  final List<double> data;
  SmoothLineChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = const Color(0xFF6366F1)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final maxData = data.reduce((a, b) => a > b ? a : b) * 1.1;
    final minData = data.reduce((a, b) => a < b ? a : b) * 0.9;
    final range = maxData - minData;

    final stepX = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - ((data[i] - minData) / range) * size.height;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevX = (i - 1) * stepX;
        final prevY = size.height - ((data[i - 1] - minData) / range) * size.height;
        final controlPointX = prevX + (x - prevX) / 2;
        path.cubicTo(controlPointX, prevY, controlPointX, y, x, y);
      }
    }

    // Draw shadow/gradient fill
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF6366F1).withOpacity(0.3),
          const Color(0xFF6366F1).withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

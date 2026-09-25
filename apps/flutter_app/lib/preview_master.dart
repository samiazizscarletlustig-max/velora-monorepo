import 'dart:ui';
import 'package:flutter/material.dart';

void main() {
  runApp(const Velora());
}

class Velora extends StatelessWidget {
  const Velora({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Velora',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF161B26),
          background: Color(0xFF0A0E1A),
        ),
        fontFamily: 'Inter', // Or any sans-serif fallback
      ),
      home: const MainPreviewNavigator(),
    );
  }
}

class MainPreviewNavigator extends StatefulWidget {
  const MainPreviewNavigator({super.key});

  @override
  State<MainPreviewNavigator> createState() => _MainPreviewNavigatorState();
}

class _MainPreviewNavigatorState extends State<MainPreviewNavigator> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const SmartNotesScreen(),
    const AnalysisHubScreen(),
    const StrategyCanvasScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(child: _screens[_currentIndex]),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
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
          _NavItem(icon: Icons.edit_note, label: 'Smart Notes\nملاحظات ذكية', isSelected: _currentIndex == 0, onTap: () => setState(() => _currentIndex = 0)),
          _NavItem(icon: Icons.analytics, label: 'Analysis Hub\nمركز التحليل', isSelected: _currentIndex == 1, onTap: () => setState(() => _currentIndex = 1)),
          _NavItem(icon: Icons.account_tree, label: 'Strategy Canvas\nلوحة الاستراتيجية', isSelected: _currentIndex == 2, onTap: () => setState(() => _currentIndex = 2)),
          const Spacer(),
          // User profile
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF161B26), borderRadius: BorderRadius.circular(12)),
            child: const Row(
              children: [
                CircleAvatar(radius: 16, backgroundColor: Colors.grey, child: Icon(Icons.person, color: Colors.white)),
                SizedBox(width: 12),
                Text('Admin User', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? Theme.of(context).colorScheme.primary : Colors.white70;
    final bg = isSelected ? color.withOpacity(0.1) : Colors.transparent;
    
    return InkWell(
      onTap: onTap,
      child: Container(
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
      ),
    );
  }
}

// ---------------------------------------------------------
// PHASE 1: SMART NOTES EDITOR
// ---------------------------------------------------------
class SmartNotesScreen extends StatelessWidget {
  const SmartNotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0E1A),
      child: Row(
        children: [
          Expanded(
            child: Column(
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
                        // Mock wiki-link
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
            ),
          ),
          _buildRightSidebar(context),
        ],
      ),
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
          const SizedBox(width: 16),
          const Icon(Icons.format_list_bulleted, color: Colors.white70, size: 20),
          const SizedBox(width: 16),
          const Icon(Icons.code, color: Colors.white70, size: 20),
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
          const Expanded(child: Text('AI Insight: Focus on Smart Home category where Amazon SA is showing inventory shortages.\nرؤية الذكاء الاصطناعي: ركز على فئة الأجهزة المنزلية الذكية حيث تعاني أمازون السعودية من نقص في المخزون.', style: TextStyle(color: Colors.amber, height: 1.5))),
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
          const Text('Backlinks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildBacklinkCard(context, 'Noon Price Tracker', 'Mentioned in Q4 planning...'),
          _buildBacklinkCard(context, 'Inventory Alerts', 'Amazon SA shortages mapped...'),
          const SizedBox(height: 32),
          const Text('Tags', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTag(context, '#strategy'),
              _buildTag(context, '#competitor-analysis'),
              _buildTag(context, '#pricing'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBacklinkCard(BuildContext context, String title, String snippet) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF222938)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link, size: 14, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Text(snippet, style: const TextStyle(color: Colors.white54, fontSize: 12)),
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

// ---------------------------------------------------------
// PHASE 2: ANALYSIS HUB
// ---------------------------------------------------------
class AnalysisHubScreen extends StatelessWidget {
  const AnalysisHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF222938)))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Analysis Hub / مركز التحليل', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh Data'),
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
              )
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B26),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF222938)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Market Share Trend / اتجاه الحصة السوقية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 32),
                      const SizedBox(height: 300, width: double.infinity, child: MockChart()),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildDeltaTable(context)),
                    const SizedBox(width: 32),
                    Expanded(flex: 1, child: _buildAiAnalyst(context)),
                  ],
                )
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildDeltaTable(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF161B26), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF222938))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(padding: EdgeInsets.all(24), child: Text('Live Price Monitor / مراقب الأسعار الحي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          const Divider(height: 1, color: Color(0xFF222938)),
          DataTable(
            headingTextStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.bold),
            columns: const [
              DataColumn(label: Text('Competitor')),
              DataColumn(label: Text('Product')),
              DataColumn(label: Text('Old')),
              DataColumn(label: Text('New')),
              DataColumn(label: Text('Delta')),
            ],
            rows: [
              _buildRow('Noon', 'iPhone 15 Pro Max', 4799, 4599, -4.16, Colors.greenAccent, Icons.arrow_downward),
              _buildRow('Amazon', 'Sony WH-1000XM5', 1299, 1450, 11.6, Colors.redAccent, Icons.arrow_upward),
              _buildRow('Jarir', 'MacBook Air M3', 5299, 4999, -5.66, Colors.greenAccent, Icons.arrow_downward),
            ],
          )
        ],
      ),
    );
  }

  DataRow _buildRow(String comp, String prod, int oldP, int newP, double delta, Color color, IconData arrow) {
    return DataRow(cells: [
      DataCell(Text(comp, style: const TextStyle(fontWeight: FontWeight.bold))),
      DataCell(Text(prod)),
      DataCell(Text('$oldP SAR', style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.white54))),
      DataCell(Text('$newP SAR', style: const TextStyle(fontWeight: FontWeight.bold))),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(arrow, size: 12, color: color),
            const SizedBox(width: 4),
            Text('${delta.abs()}%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      )),
    ]);
  }

  Widget _buildAiAnalyst(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFF161B26), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF222938))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('AI Analyst', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          _buildInsight(context, 'Noon Price Drop', 'Match prices on top 20 SKUs to retain share.', Icons.warning_amber_rounded, Colors.redAccent),
          const SizedBox(height: 16),
          _buildInsight(context, 'Amazon Shortage', 'Increase ad spend on smart home keywords.', Icons.lightbulb_outline, Colors.greenAccent),
        ],
      ),
    );
  }

  Widget _buildInsight(BuildContext context, String title, String rec, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF0A0E1A), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF222938))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.subdirectory_arrow_right, color: Theme.of(context).colorScheme.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(rec, style: const TextStyle(fontSize: 13, height: 1.4))),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class MockChart extends StatelessWidget {
  const MockChart({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MockChartPainter(Theme.of(context)),
    );
  }
}

class _MockChartPainter extends CustomPainter {
  final ThemeData theme;
  _MockChartPainter(this.theme);

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()..color = Colors.blueAccent..strokeWidth = 3..style = PaintingStyle.stroke;
    final paint2 = Paint()..color = Colors.yellowAccent..strokeWidth = 3..style = PaintingStyle.stroke;
      
    final path1 = Path();
    path1.moveTo(0, size.height * 0.8);
    path1.cubicTo(size.width * 0.25, size.height * 0.8, size.width * 0.25, size.height * 0.4, size.width * 0.5, size.height * 0.5);
    path1.cubicTo(size.width * 0.75, size.height * 0.6, size.width * 0.75, size.height * 0.2, size.width, size.height * 0.1);
    
    final path2 = Path();
    path2.moveTo(0, size.height * 0.5);
    path2.cubicTo(size.width * 0.3, size.height * 0.6, size.width * 0.5, size.height * 0.7, size.width * 0.7, size.height * 0.4);
    path2.cubicTo(size.width * 0.8, size.height * 0.2, size.width * 0.9, size.height * 0.3, size.width, size.height * 0.5);

    canvas.drawPath(path1, paint1);
    canvas.drawPath(path2, paint2);

    // Gradient fills
    final fillPaint1 = Paint()
      ..shader = ui.Gradient.linear(Offset(0, 0), Offset(0, size.height), [Colors.blueAccent.withOpacity(0.3), Colors.transparent])
      ..style = PaintingStyle.fill;
    final fillPath1 = Path.from(path1)..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(fillPath1, fillPaint1);

    // Grid lines
    final gridPaint = Paint()..color = Colors.white10..strokeWidth = 1;
    for(int i=0; i<=4; i++) {
      canvas.drawLine(Offset(0, size.height * (i/4)), Offset(size.width, size.height * (i/4)), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------
// PHASE 3: STRATEGY CANVAS
// ---------------------------------------------------------
class StrategyCanvasScreen extends StatefulWidget {
  const StrategyCanvasScreen({super.key});

  @override
  State<StrategyCanvasScreen> createState() => _StrategyCanvasScreenState();
}

class _StrategyCanvasScreenState extends State<StrategyCanvasScreen> {
  final TransformationController _controller = TransformationController();
  
  List<Offset> nodePositions = [
    const Offset(100, 150),
    const Offset(500, 100),
    const Offset(500, 350),
    const Offset(900, 200),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF222938)))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.account_tree, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 16),
                  const Text('Strategy Canvas / لوحة الاستراتيجية', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Share Board'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF161B26), foregroundColor: Colors.white, side: const BorderSide(color: Color(0xFF222938))),
              )
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              ClipRect(
                child: InteractiveViewer(
                  transformationController: _controller,
                  boundaryMargin: const EdgeInsets.all(2000),
                  minScale: 0.1,
                  maxScale: 2.0,
                  constrained: false,
                  child: SizedBox(
                    width: 4000,
                    height: 4000,
                    child: Stack(
                      children: [
                        CustomPaint(
                          size: const Size(4000, 4000),
                          painter: _CanvasConnectionsPainter(nodePositions, Theme.of(context)),
                        ),
                        _buildNode(0, 'Q4 Pricing Aggression\nتسعير هجومي', 'Drop prices by 10% on flagship items to counter Noon.', const Color(0xFF3B82F6), Icons.attach_money),
                        _buildNode(1, 'Exclusive Bundles\nباقات حصرية', 'Partner with local brands for unique bundles.', const Color(0xFF8B5CF6), Icons.inventory_2),
                        _buildNode(2, 'TikTok Influencer Push\nحملة تيك توك', 'Allocate 40% of ad spend to TikTok creators.', const Color(0xFF10B981), Icons.campaign),
                        _buildNode(3, 'Same-Day Delivery\nتوصيل في نفس اليوم', 'Launch fast logistics in Dammam and Jeddah.', const Color(0xFFF59E0B), Icons.local_shipping),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 32,
                left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B26).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: const Color(0xFF222938)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10))],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pan_tool, color: Colors.white, size: 20),
                        SizedBox(width: 16),
                        Icon(Icons.near_me, color: Colors.white54, size: 20),
                        SizedBox(width: 16),
                        Text('100%', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              )
            ],
          ),
        )
      ],
    );
  }

  Widget _buildNode(int index, String title, String desc, Color color, IconData icon) {
    return Positioned(
      left: nodePositions[index].dx,
      top: nodePositions[index].dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            nodePositions[index] += details.delta / _controller.value.getMaxScaleOnAxis();
          });
        },
        child: Container(
          width: 280,
          decoration: BoxDecoration(
            color: const Color(0xFF161B26).withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 8)),
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  border: Border(bottom: BorderSide(color: color.withOpacity(0.2))),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: color, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(title.split('\n').first.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.2))),
                    const Icon(Icons.drag_indicator, color: Colors.white30, size: 16),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, height: 1.3, fontSize: 15)),
                    const SizedBox(height: 8),
                    Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CanvasConnectionsPainter extends CustomPainter {
  final List<Offset> nodes;
  final ThemeData theme;
  _CanvasConnectionsPainter(this.nodes, this.theme);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = Colors.white.withOpacity(0.02)..style = PaintingStyle.fill;
    for (double x = 0; x < size.width; x += 40) {
      for (double y = 0; y < size.height; y += 40) {
        canvas.drawCircle(Offset(x, y), 1.5, gridPaint);
      }
    }

    final paint = Paint()..color = Colors.white.withOpacity(0.2)..strokeWidth = 2.5..style = PaintingStyle.stroke;

    if (nodes.length >= 4) {
      _drawConnection(canvas, nodes[0], nodes[1], paint, 'Offsets margin loss');
      _drawConnection(canvas, nodes[0], nodes[3], paint, 'Requires fast logistics');
      _drawConnection(canvas, nodes[1], nodes[2], paint, 'Primary focus');
    }
  }

  void _drawConnection(Canvas canvas, Offset start, Offset end, Paint paint, String label) {
    final s = Offset(start.dx + 280, start.dy + 80);
    final e = Offset(end.dx, end.dy + 80);

    final path = Path();
    path.moveTo(s.dx, s.dy);
    
    final ctrlDist = (e.dx - s.dx).abs() * 0.4;
    path.cubicTo(s.dx + ctrlDist, s.dy, e.dx - ctrlDist, e.dy, e.dx, e.dy);
    canvas.drawPath(path, paint);

    // Draw label
    final midX = (s.dx + e.dx) / 2;
    final midY = (s.dy + e.dy) / 2;
    
    final textPainter = TextPainter(
      text: TextSpan(text: label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();

    final rect = Rect.fromCenter(center: Offset(midX, midY), width: textPainter.width + 16, height: textPainter.height + 8);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), Paint()..color = const Color(0xFF161B26));
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), Paint()..color = Colors.white24..style = PaintingStyle.stroke);
    textPainter.paint(canvas, Offset(midX - textPainter.width / 2, midY - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

import 'package:flutter/material.dart';

/// 📱 STRATEGY CANVAS - VELORA STRATEGIC OS
/// Fully Responsive: Desktop, Tablet, Mobile
class StrategyCanvas extends StatefulWidget {
  const StrategyCanvas({Key? key}) : super(key: key);

  @override
  State<StrategyCanvas> createState() => _StrategyCanvasState();
}

class _StrategyCanvasState extends State<StrategyCanvas> {
  // --- Premium Dark Theme Colors ---
  final Color _bgColor = const Color(0xFF0A0E1A);
  final Color _panelColor = const Color(0xFF131A2B);
  final Color _glassColor = const Color(0x1AFFFFFF); 
  final Color _borderColor = const Color(0x1FFFFFFF);
  final Color _accentColor = const Color(0xFF8B5CF6); // Purple accent for strategy
  final Color _textColor = const Color(0xFFF8FAFC);
  final Color _textMuted = const Color(0xFF94A3B8);

  int _mobileNavIndex = 3; // Default to Strategy

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    
    // 📏 Breakpoints
    final bool isMobile = width < 768;
    final bool isTablet = width >= 768 && width < 1200;
    final bool isDesktop = width >= 1200;

    return Scaffold(
      backgroundColor: _bgColor,
      // 📱 Mobile / Tablet Drawer
      drawer: !isDesktop ? Drawer(backgroundColor: _panelColor, child: _buildLeftSidebar(isMobile: true)) : null,
      
      // 📱 Mobile Bottom Nav
      bottomNavigationBar: isMobile ? _buildBottomNav() : null,
      
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 💻 Desktop Sidebar
            if (isDesktop) _buildLeftSidebar(isMobile: false),
            
            // 🗺️ Main Canvas Area
            Expanded(
              child: Stack(
                children: [
                  _buildCanvasArea(isMobile: isMobile),
                  
                  // 📱 Sticky Header for Mobile/Tablet to access drawer
                  if (!isDesktop) _buildMobileHeader(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 1. NAVIGATION
  // =========================================================================
  Widget _buildLeftSidebar({required bool isMobile}) {
    return Container(
      width: isMobile ? double.infinity : 260,
      decoration: BoxDecoration(
        color: _panelColor,
        border: Border(right: BorderSide(color: _borderColor, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Text("Velora", style: TextStyle(color: _textColor, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ],
            ),
          ),
          Divider(color: _borderColor, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              children: [
                _navItem(Icons.hub_outlined, "Analysis Hub", false),
                _navItem(Icons.architecture, "Strategy Canvas", true),
                _navItem(Icons.edit_document, "Smart Notes", false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String title, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isActive ? _glassColor : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: isActive ? Border.all(color: _borderColor) : Border.all(color: Colors.transparent),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(icon, color: isActive ? _accentColor : _textMuted, size: 20),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? _textColor : _textMuted,
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        onTap: () {},
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _panelColor,
        border: Border(top: BorderSide(color: _borderColor)),
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _accentColor,
        unselectedItemColor: _textMuted,
        currentIndex: _mobileNavIndex,
        onTap: (index) => setState(() => _mobileNavIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.hub_outlined), label: 'Hub'),
          BottomNavigationBarItem(icon: Icon(Icons.edit_document), label: 'Notes'),
          BottomNavigationBarItem(icon: Icon(Icons.architecture), label: 'Strategy'),
        ],
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        height: 60,
        color: _bgColor.withOpacity(0.8),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Builder(
              builder: (ctx) => IconButton(
                icon: Icon(Icons.menu, color: _textColor),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            const Spacer(),
            Icon(Icons.more_vert, color: _textColor),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 2. CANVAS AREA (Infinite Board Mockup)
  // =========================================================================
  Widget _buildCanvasArea({required bool isMobile}) {
    return Stack(
      children: [
        // Grid Background
        CustomPaint(
          size: Size.infinite,
          painter: _GridPainter(gridColor: _borderColor),
        ),
        
        // Toolbar (Floating)
        Positioned(
          top: isMobile ? 80 : 30,
          left: 30,
          right: 30,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Q3 Positioning Map",
                style: TextStyle(color: _textColor, fontSize: isMobile ? 20 : 28, fontWeight: FontWeight.bold),
              ),
              if (!isMobile)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _panelColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Row(
                    children: [
                      IconButton(icon: Icon(Icons.undo, color: _textMuted, size: 18), onPressed: () {}),
                      IconButton(icon: Icon(Icons.redo, color: _textMuted, size: 18), onPressed: () {}),
                      Container(width: 1, height: 20, color: _borderColor),
                      IconButton(icon: Icon(Icons.share_outlined, color: _textColor, size: 18), onPressed: () {}),
                    ],
                  ),
                )
            ],
          ),
        ),

        // Node Mocks
        // In a real app, this would be an InteractiveViewer with drag-and-drop
        // We use absolute positioning here to mock the flowchart look
        Positioned(
          top: 150, left: isMobile ? 20 : 100,
          child: _buildCanvasNode(
            title: "Market Problem",
            content: "High churn rate in entry-tier users due to lack of onboarding.",
            color: const Color(0xFFEF4444),
          ),
        ),

        Positioned(
          top: isMobile ? 320 : 150, left: isMobile ? 20 : 450,
          child: _buildCanvasNode(
            title: "Core Strategy",
            content: "Deploy automated AI onboarding sequence.",
            color: const Color(0xFF3B82F6),
          ),
        ),

        Positioned(
          top: isMobile ? 490 : 350, left: isMobile ? 20 : 450,
          child: _buildCanvasNode(
            title: "Expected Outcome",
            content: "Reduce churn by 5% over next 60 days.",
            color: const Color(0xFF10B981),
          ),
        ),

        // Connection Lines (Mocked via CustomPaint)
        if (!isMobile)
          Positioned.fill(
            child: CustomPaint(
              painter: _ConnectionPainter(lineColor: _textMuted.withOpacity(0.5)),
            ),
          ),
      ],
    );
  }

  Widget _buildCanvasNode({required String title, required String content, required Color color}) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              Icon(Icons.more_horiz, color: _textMuted, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Text(content, style: TextStyle(color: _textMuted, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color gridColor;
  _GridPainter({required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor.withOpacity(0.3)
      ..strokeWidth = 1;

    const double spacing = 40.0;
    
    // Draw vertical lines
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    
    // Draw horizontal lines
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ConnectionPainter extends CustomPainter {
  final Color lineColor;
  _ConnectionPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw mock bezier curve connecting Node 1 to Node 2
    final path = Path();
    path.moveTo(380, 200); // Approximate exit point of Node 1
    path.cubicTo(410, 200, 420, 200, 450, 200); // Connect to Node 2
    canvas.drawPath(path, paint);
    
    // Connect Node 2 to Node 3
    final path2 = Path();
    path2.moveTo(590, 260); 
    path2.cubicTo(590, 300, 590, 310, 590, 350); 
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

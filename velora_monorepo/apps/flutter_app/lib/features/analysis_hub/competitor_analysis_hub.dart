import 'dart:ui';
import 'package:flutter/material.dart';

/// 📱 COMPETITOR ANALYSIS HUB - VELORA STRATEGIC OS
/// Fully Responsive: Desktop, Tablet, Mobile
class CompetitorAnalysisHub extends StatefulWidget {
  const CompetitorAnalysisHub({Key? key}) : super(key: key);

  @override
  State<CompetitorAnalysisHub> createState() => _CompetitorAnalysisHubState();
}

class _CompetitorAnalysisHubState extends State<CompetitorAnalysisHub> {
  // --- Premium Dark Theme Colors ---
  final Color _bgColor = const Color(0xFF0A0E1A);
  final Color _panelColor = const Color(0xFF131A2B);
  final Color _glassColor = const Color(0x1AFFFFFF); 
  final Color _borderColor = const Color(0x1FFFFFFF);
  final Color _accentColor = const Color(0xFF3B82F6); 
  final Color _successColor = const Color(0xFF10B981);
  final Color _warningColor = const Color(0xFFF59E0B);
  final Color _dangerColor = const Color(0xFFEF4444);
  final Color _textColor = const Color(0xFFF8FAFC);
  final Color _textMuted = const Color(0xFF94A3B8);

  int _mobileNavIndex = 1; // Default to Hub
  String _selectedFilter = 'All Competitors';

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    
    // 📏 Breakpoints
    final bool isMobile = width < 768;
    final bool isTablet = width >= 768 && width < 1200;
    final bool isDesktop = width >= 1200;
    
    // Adjust layout columns based on width
    int crossAxisCount = isMobile ? 1 : (isTablet ? 2 : 3);

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
            
            // 📊 Main Dashboard Area
            Expanded(
              child: Stack(
                children: [
                  _buildDashboardCanvas(isMobile: isMobile, isTablet: isTablet, crossAxisCount: crossAxisCount),
                  
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
  // 1. NAVIGATION (Shared with Notes)
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
                _navItem(Icons.hub_outlined, "Analysis Hub", true),
                _navItem(Icons.architecture, "Strategy Canvas", false),
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
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 60,
            color: _bgColor.withOpacity(0.6),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _glassColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sync, color: _accentColor, size: 14),
                      const SizedBox(width: 6),
                      Text("Live", style: TextStyle(color: _textColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 2. DASHBOARD CANVAS
  // =========================================================================
  Widget _buildDashboardCanvas({required bool isMobile, required bool isTablet, required int crossAxisCount}) {
    final double padding = isMobile ? 20.0 : 40.0;
    
    return ListView(
      padding: EdgeInsets.only(
        left: padding, 
        right: padding, 
        top: isMobile ? 80 : padding, 
        bottom: isMobile ? 100 : padding
      ),
      children: [
        // Top Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("MARKET INTELLIGENCE", style: TextStyle(color: _textMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Text("Competitor Hub", style: TextStyle(color: _textColor, fontSize: isMobile ? 28 : 36, fontWeight: FontWeight.bold)),
              ],
            ),
            if (!isMobile)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _glassColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _borderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.sync, color: _accentColor, size: 16),
                    const SizedBox(width: 8),
                    Text("Last synced: 12 mins ago", style: TextStyle(color: _textMuted, fontSize: 13)),
                  ],
                ),
              ),
          ],
        ),
        
        const SizedBox(height: 32),
        
        // Filter Bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('All Competitors', true),
              _buildFilterChip('Direct Threats', false),
              _buildFilterChip('Emerging', false),
              _buildFilterChip('Pricing Changes', false),
              const SizedBox(width: 16),
              Container(
                width: 1, height: 24, color: _borderColor,
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
              const SizedBox(width: 16),
              Icon(Icons.filter_list, color: _textMuted, size: 20),
              const SizedBox(width: 8),
              Text("More Filters", style: TextStyle(color: _textMuted, fontSize: 14)),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Main Grid (Health Scores & KPIs)
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: isMobile ? 2.2 : 1.6,
          children: [
            _buildMetricCard("Apex Dynamics", "84/100", "+2.4%", Icons.trending_up, _successColor),
            _buildMetricCard("StellarTech", "62/100", "-5.1%", Icons.trending_down, _dangerColor),
            _buildMetricCard("Nova Prime", "78/100", "0.0%", Icons.drag_handle, _textMuted),
          ],
        ),
        
        const SizedBox(height: 32),
        
        // AI Insights Feed (Glassmorphism List)
        Row(
          children: [
            Icon(Icons.auto_awesome, color: _accentColor, size: 20),
            const SizedBox(width: 12),
            Text("AI Strategy Insights", style: TextStyle(color: _textColor, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 20),
        
        _buildInsightCard(
          title: "Apex Dynamics dropped Base Tier pricing",
          competitor: "Apex Dynamics",
          threatLevel: "High",
          threatColor: _dangerColor,
          description: "Apex Dynamics reduced their entry-level subscription by 15% to capture down-market users. We recommend promoting our value-adds to prevent churn.",
          time: "2 hours ago",
        ),
        const SizedBox(height: 16),
        _buildInsightCard(
          title: "StellarTech out of stock on flagship SKU",
          competitor: "StellarTech",
          threatLevel: "Opportunity",
          threatColor: _successColor,
          description: "Primary flagship hardware has been marked out-of-stock for 48 hours. Opportunity to increase ad spend targeting their branded keywords.",
          time: "5 hours ago",
        ),
        
        const SizedBox(height: 32),
        
        // Interactive Chart Area Mockup
        Container(
          width: double.infinity,
          height: 300,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _panelColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Pricing Volatility (30 Days)", style: TextStyle(color: _textColor, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Expanded(
                child: CustomPaint(
                  size: const Size(double.infinity, double.infinity),
                  painter: _MockChartPainter(accentColor: _accentColor, secondaryColor: _dangerColor),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildChartLegend("Velora (Us)", _accentColor),
                  const SizedBox(width: 24),
                  _buildChartLegend("Market Average", _dangerColor),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // HELPER WIDGETS
  // =========================================================================
  Widget _buildFilterChip(String label, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _textColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? _textColor : _borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? _bgColor : _textMuted,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String score, String change, IconData trendIcon, Color trendColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: _textMuted, fontSize: 14, fontWeight: FontWeight.w600)),
              Icon(Icons.more_horiz, color: _textMuted, size: 20),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(score, style: TextStyle(color: _textColor, fontSize: 32, fontWeight: FontWeight.bold, height: 1.0)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: trendColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(trendIcon, color: trendColor, size: 14),
                    const SizedBox(width: 4),
                    Text(change, style: TextStyle(color: trendColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildInsightCard({
    required String title, required String competitor, required String threatLevel, 
    required Color threatColor, required String description, required String time
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _glassColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: threatColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: threatColor.withOpacity(0.3)),
                ),
                child: Text(threatLevel.toUpperCase(), style: TextStyle(color: threatColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
              ),
              const SizedBox(width: 12),
              Text(competitor, style: TextStyle(color: _textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(time, style: TextStyle(color: _textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(description, style: TextStyle(color: _textMuted, fontSize: 14, height: 1.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              Text("Generate Counter-Strategy", style: TextStyle(color: _accentColor, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward, color: _accentColor, size: 14),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildChartLegend(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: _textMuted, fontSize: 13)),
      ],
    );
  }
}

// Custom Painter for Mock Chart using smooth curves
class _MockChartPainter extends CustomPainter {
  final Color accentColor;
  final Color secondaryColor;

  _MockChartPainter({required this.accentColor, required this.secondaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = accentColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paint2 = Paint()
      ..color = secondaryColor.withOpacity(0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw Grid Lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;
      
    for (int i = 0; i < 5; i++) {
      final double y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Line 1 (Velora)
    final path1 = Path();
    path1.moveTo(0, size.height * 0.7);
    path1.quadraticBezierTo(size.width * 0.25, size.height * 0.9, size.width * 0.5, size.height * 0.5);
    path1.quadraticBezierTo(size.width * 0.75, size.height * 0.1, size.width, size.height * 0.3);
    canvas.drawPath(path1, paint1);

    // Line 2 (Competitor)
    final path2 = Path();
    path2.moveTo(0, size.height * 0.4);
    path2.quadraticBezierTo(size.width * 0.3, size.height * 0.2, size.width * 0.6, size.height * 0.6);
    path2.quadraticBezierTo(size.width * 0.8, size.height * 0.8, size.width, size.height * 0.5);
    canvas.drawPath(path2, paint2);

    // Gradient fill under Line 1
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [accentColor.withOpacity(0.2), accentColor.withOpacity(0.0)],
      ).createShader(Rect.fromLTRB(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
      
    final fillPath = Path.from(path1)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
      
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

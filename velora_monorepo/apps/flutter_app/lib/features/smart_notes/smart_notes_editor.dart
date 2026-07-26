import 'dart:ui';
import 'package:flutter/material.dart';

/// 📱 SMART NOTES EDITOR - VELORA STRATEGIC OS
/// Fully Responsive: Desktop, Tablet, Mobile
class SmartNotesEditor extends StatefulWidget {
  const SmartNotesEditor({Key? key}) : super(key: key);

  @override
  State<SmartNotesEditor> createState() => _SmartNotesEditorState();
}

class _SmartNotesEditorState extends State<SmartNotesEditor> {
  // --- Premium Dark Theme Colors ---
  final Color _bgColor = const Color(0xFF0A0E1A);
  final Color _panelColor = const Color(0xFF131A2B);
  final Color _glassColor = const Color(0x1AFFFFFF); 
  final Color _borderColor = const Color(0x1FFFFFFF);
  final Color _accentColor = const Color(0xFF3B82F6); 
  final Color _textColor = const Color(0xFFF8FAFC);
  final Color _textMuted = const Color(0xFF94A3B8);

  int _mobileNavIndex = 2; // Default to Notes

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    
    // 📏 Breakpoints
    final bool isMobile = width < 768;
    final bool isTablet = width >= 768 && width < 1200;
    final bool isDesktop = width >= 1200;
    
    // Show right panel on Desktop, or large tablets
    final bool showRightPanel = isDesktop || (isTablet && width >= 900);

    return Scaffold(
      backgroundColor: _bgColor,
      // 📱 Mobile / Tablet Drawers
      drawer: !isDesktop ? Drawer(backgroundColor: _panelColor, child: _buildLeftSidebar(isMobile: true)) : null,
      endDrawer: !showRightPanel ? Drawer(backgroundColor: _panelColor, child: _buildRightSidebar(isMobile: true)) : null,
      
      // 📱 Mobile Bottom Nav
      bottomNavigationBar: isMobile ? _buildBottomNav() : null,
      
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 💻 Desktop Sidebar
            if (isDesktop) _buildLeftSidebar(isMobile: false),
            
            // 📝 Main Editor Area
            Expanded(
              child: Stack(
                children: [
                  _buildEditorCanvas(isMobile: isMobile, isTablet: isTablet),
                  
                  // 📱 Sticky Header for Mobile/Tablet to access drawers
                  if (!isDesktop) _buildMobileHeader(isMobile),
                ],
              ),
            ),
            
            // 💻 Desktop / Large Tablet Right Panel
            if (showRightPanel) _buildRightSidebar(isMobile: false),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 1. NAVIGATION (LEFT SIDEBAR & BOTTOM NAV)
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
          // Workspace Header
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
                const Spacer(),
                Icon(Icons.unfold_more, color: _textMuted, size: 16),
              ],
            ),
          ),
          Divider(color: _borderColor, height: 1),
          
          // Navigation Links
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              children: [
                _navItem(Icons.hub_outlined, "Analysis Hub", false),
                _navItem(Icons.architecture, "Strategy Canvas", false),
                _navItem(Icons.edit_document, "Smart Notes", true),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 8),
                  child: Text("FAVORITES", style: TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
                _navItem(Icons.article_outlined, "Q3 Market Expansion", false, isNested: true),
                _navItem(Icons.article_outlined, "Competitor Pricing DB", false, isNested: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String title, bool isActive, {bool isNested = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isActive ? _glassColor : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: isActive ? Border.all(color: _borderColor) : Border.all(color: Colors.transparent),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.only(left: isNested ? 24 : 12, right: 12),
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

  Widget _buildMobileHeader(bool isMobile) {
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
                if (isMobile) 
                  Builder(
                    builder: (ctx) => IconButton(
                      icon: Icon(Icons.info_outline, color: _textColor),
                      onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 2. MAIN EDITOR CANVAS
  // =========================================================================
  Widget _buildEditorCanvas({required bool isMobile, required bool isTablet}) {
    final double paddingHorizontal = isMobile ? 20.0 : (isTablet ? 40.0 : 80.0);
    
    return Container(
      color: _bgColor,
      child: CustomScrollView(
        slivers: [
          // Cover Image Area
          SliverToBoxAdapter(
            child: Container(
              height: isMobile ? 160 : 240,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage('https://images.unsplash.com/photo-1557683316-973673baf926?q=80&w=2000&auto=format&fit=crop'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, _bgColor],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: paddingHorizontal,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _borderColor),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.image_outlined, color: Colors.white, size: 14),
                          const SizedBox(width: 8),
                          Text("Change Cover", style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
          
          // Document Content Area
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: paddingHorizontal, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  TextField(
                    style: TextStyle(
                      fontSize: isMobile ? 32 : 46, 
                      fontWeight: FontWeight.w800, 
                      color: Colors.white, 
                      height: 1.2
                    ),
                    decoration: const InputDecoration(
                      hintText: "Untitled Document",
                      hintStyle: TextStyle(color: Colors.white24),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    controller: TextEditingController.text("Q3 Competitor Pricing Strategy 📊"),
                  ),
                  const SizedBox(height: 24),
                  
                  // Mocked Rich Content Blocks
                  _buildCalloutBlock(
                    icon: Icons.lightbulb_outline,
                    color: Colors.amber,
                    title: "Strategic Directive / التوجيه الاستراتيجي",
                    content: "يجب مراقبة تغييرات أسعار المنافسين خلال هذا الربع بعناية. Our primary competitor has lowered their entry-tier by 15%.",
                  ),
                  const SizedBox(height: 24),
                  
                  Text("Key Observations", style: TextStyle(color: _textColor, fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  
                  RichText(
                    text: TextSpan(
                      style: TextStyle(color: _textColor.withOpacity(0.85), fontSize: isMobile ? 15 : 16, height: 1.6),
                      children: [
                        const TextSpan(text: "Based on the delta analysis from last week, we've identified three core patterns in the market. Check the link to "),
                        TextSpan(
                          text: "[[Competitor X Analysis]]",
                          style: TextStyle(color: _accentColor, backgroundColor: _accentColor.withOpacity(0.15)),
                        ),
                        const TextSpan(text: " for raw data."),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Task List
                  _buildTodoItem("Analyze pricing elasticity for Tier 1 products", true),
                  _buildTodoItem("Update marketing copy to highlight value over price", false),
                  _buildTodoItem("Review AI insights for customer churn risk / مراجعة مخاطر خسارة العملاء", false),
                  
                  const SizedBox(height: 32),
                  
                  // Code / Data Block
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D121C),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text("JSON", style: TextStyle(color: _textMuted, fontSize: 12, fontFamily: 'monospace')),
                            const Spacer(),
                            Icon(Icons.copy, color: _textMuted, size: 14),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '{\n  "competitor": "ShopifyPlus",\n  "delta_change": "-15%",\n  "threat_level": "high"\n}',
                          style: TextStyle(color: Color(0xFF4ADE80), fontSize: 14, fontFamily: 'monospace', height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  
                  // Padding for bottom toolbar on mobile
                  SizedBox(height: isMobile ? 100 : 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 3. METADATA & BACKLINKS (RIGHT SIDEBAR)
  // =========================================================================
  Widget _buildRightSidebar({required bool isMobile}) {
    return Container(
      width: isMobile ? double.infinity : 300,
      decoration: BoxDecoration(
        color: _panelColor,
        border: Border(left: BorderSide(color: _borderColor, width: 1)),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (isMobile) ...[
              Row(
                children: [
                  Text("DOCUMENT INFO", style: TextStyle(color: _textColor, fontSize: 14, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: _textMuted),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Properties
            Text("PROPERTIES", style: TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 16),
            
            _buildPropertyRow(Icons.calendar_today, "Created", "Today at 10:42 AM"),
            const SizedBox(height: 14),
            _buildPropertyRow(Icons.person_outline, "Author", "Sami Aziz"),
            const SizedBox(height: 14),
            _buildPropertyRow(Icons.label_outline, "Tags", "Strategy, Pricing", isTag: true),
            
            const SizedBox(height: 32),
            Divider(color: _borderColor),
            const SizedBox(height: 24),
            
            // Backlinks
            Row(
              children: [
                Text("BACKLINKS", style: TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _glassColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text("3", style: TextStyle(color: _textColor, fontSize: 10)),
                )
              ],
            ),
            const SizedBox(height: 16),
            
            _buildBacklinkCard("Weekly Sync Notes", "Mentioned in discussion about Q3 pricing adjustments."),
            const SizedBox(height: 12),
            _buildBacklinkCard("Competitor Dashboard", "Linked as a primary strategic reference."),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // HELPER WIDGETS
  // =========================================================================
  Widget _buildCalloutBlock({required IconData icon, required Color color, required String title, required String content}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 6),
                Text(content, style: TextStyle(color: _textColor.withOpacity(0.9), fontSize: 14, height: 1.5)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTodoItem(String text, bool isChecked) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: isChecked ? _accentColor : Colors.transparent,
              border: Border.all(color: isChecked ? _accentColor : _textMuted, width: 1.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: isChecked ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isChecked ? _textMuted : _textColor,
                fontSize: 15,
                height: 1.4,
                decoration: isChecked ? TextDecoration.lineThrough : TextDecoration.none,
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPropertyRow(IconData icon, String label, String value, {bool isTag = false}) {
    return Row(
      children: [
        Icon(icon, color: _textMuted, size: 16),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: Text(label, style: TextStyle(color: _textMuted, fontSize: 13)),
        ),
        Expanded(
          child: isTag 
            ? Wrap(
                spacing: 6,
                runSpacing: 6,
                children: value.split(', ').map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _glassColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Text(tag, style: TextStyle(color: _accentColor, fontSize: 12, fontWeight: FontWeight.w500)),
                )).toList(),
              )
            : Text(value, style: TextStyle(color: _textColor, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildBacklinkCard(String title, String context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _glassColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Text(context, style: TextStyle(color: _textMuted, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }
}

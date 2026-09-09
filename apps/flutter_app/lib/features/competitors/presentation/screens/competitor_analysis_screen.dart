import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/config/app_colors.dart';
import '../../../../core/widgets/premium_widgets.dart';

// ═══════════════════════════════════════════════════════════
// 🧠 COMPETITOR ANALYSIS SCREEN — AI INSIGHTS VIEW
// ═══════════════════════════════════════════════════════════
class CompetitorAnalysisScreen extends ConsumerStatefulWidget {
  final String competitorId;
  final String competitorName;

  const CompetitorAnalysisScreen({
    super.key,
    required this.competitorId,
    required this.competitorName,
  });

  @override
  ConsumerState<CompetitorAnalysisScreen> createState() =>
      _CompetitorAnalysisScreenState();
}

class _CompetitorAnalysisScreenState extends ConsumerState<CompetitorAnalysisScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _insights = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchInsights();
  }

  Future<void> _fetchInsights() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _supabase
          .from('ai_insights')
          .select()
          .eq('competitor_id', widget.competitorId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _insights = List<Map<String, dynamic>>.from(response ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // 🎨 Dynamic Styling Helpers
  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical': return Colors.red.shade600;
      case 'high': return Colors.orange.shade600;
      case 'medium': return Colors.blue.shade600;
      case 'low': return Colors.green.shade600;
      default: return Colors.grey.shade600;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pricing': return Icons.attach_money_rounded;
      case 'opportunity': return Icons.trending_up_rounded;
      case 'threat': return Icons.warning_amber_rounded;
      case 'portfolio': return Icons.category_rounded;
      default: return Icons.auto_awesome_rounded;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'pricing': return Colors.purple.shade600;
      case 'opportunity': return Colors.green.shade600;
      case 'threat': return Colors.red.shade600;
      case 'portfolio': return Colors.blue.shade600;
      default: return AppColors.darkAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedGradientBackground(
        child: CustomScrollView(
          slivers: [
            // ═══ App Bar ═══
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 70, bottom: 16),
                title: Text(
                  widget.competitorName.isNotEmpty ? widget.competitorName : 'Competitor',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    letterSpacing: -0.5,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.darkAccent.withOpacity(0.2),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _isLoading ? null : _fetchInsights,
                  tooltip: 'Refresh Insights',
                ),
              ],
            ),

            // ═══ Content ═══
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: _ErrorState(error: _error!, onRetry: _fetchInsights),
              )
            else if (_insights.isEmpty)
              SliverFillRemaining(
                child: _EmptyState(competitorName: widget.competitorName),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final insight = _insights[index];
                      return _InsightCard(
                        insight: insight,
                        getSeverityColor: _getSeverityColor,
                        getTypeIcon: _getTypeIcon,
                        getTypeColor: _getTypeColor,
                      ).animate().fadeIn(duration: 400.ms, delay: Duration(milliseconds: 100 * index)).slideY(begin: 0.1, end: 0);
                    },
                    childCount: _insights.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 💎 INSIGHT CARD WIDGET
// ═══════════════════════════════════════════════════════════
class _InsightCard extends StatelessWidget {
  final Map<String, dynamic> insight;
  final Color Function(String) getSeverityColor;
  final IconData Function(String) getTypeIcon;
  final Color Function(String) getTypeColor;

  const _InsightCard({
    required this.insight,
    required this.getSeverityColor,
    required this.getTypeIcon,
    required this.getTypeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // ✅ Safe type casting to prevent assertion errors
    final type = (insight['type'] ?? 'general').toString().toLowerCase();
    final severity = (insight['severity'] ?? 'medium').toString().toLowerCase();
    final severityColor = getSeverityColor(severity);
    final typeColor = getTypeColor(type);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Type, Title, Severity
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(getTypeIcon(type), color: typeColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (insight['title'] ?? 'Strategic Insight').toString(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: severityColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: severityColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: severityColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            severity.toUpperCase(),
                            style: TextStyle(
                              color: severityColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 20),

          // Summary Section (Using Markdown for bullet points)
          Text(
            '📊 Analysis Summary',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          MarkdownBody(
            data: (insight['summary'] ?? '').isEmpty ? 'No summary available.' : insight['summary'].toString(),
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              ),
              listBullet: TextStyle(
                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          const SizedBox(height: 24),

          // AI Recommendation Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.darkAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.darkAccent.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.darkAccent),
                    const SizedBox(width: 8),
                    Text(
                      'AI Recommendation',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkAccent,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                MarkdownBody(
                  data: (insight['ai_recommendation'] ?? '').isEmpty ? 'No recommendations available.' : insight['ai_recommendation'].toString(),
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                    ),
                    listBullet: TextStyle(
                      color: AppColors.darkAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          
          // Timestamp
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                (insight['created_at'] != null && insight['created_at'].toString().isNotEmpty)
                    ? timeago.format(DateTime.parse(insight['created_at'].toString())) 
                    : 'Recently',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🕳️ EMPTY STATE
// ═══════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  final String competitorName;
  const _EmptyState({required this.competitorName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: AppColors.warning, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              'No AI Insights Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'The AI engine hasn\'t analyzed $competitorName yet. Go back and trigger a scan to generate strategic insights.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                    height: 1.6,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            GradientButton(
              text: 'Go Back',
              icon: Icons.arrow_back_rounded,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ⚠️ ERROR STATE
// ═══════════════════════════════════════════════════════════
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.danger, size: 48),
            const SizedBox(height: 16),
            Text(
              'Failed to load insights',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            GradientButton(
              text: 'Try Again',
              icon: Icons.refresh_rounded,
              gradient: AppColors.dangerGradient,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
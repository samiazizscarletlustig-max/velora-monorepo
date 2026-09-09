import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_colors.dart';
import '../../../../core/extensions/widget_extensions.dart';
import '../../../../core/widgets/premium_widgets.dart';
import '../providers/dashboard_providers.dart';
import '../../data/dashboard_repository.dart';

// ═══════════════════════════════════════════════════════════
// 🎯 DASHBOARD SCREEN — AI PREMIUM EDITION
// The command center of Velora — where strategy meets data.
// ══════════════════════════════════════════════════════════
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final insightsAsync = ref.watch(recentInsightsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedGradientBackground(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _HeroHeader()),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              sliver: SliverToBoxAdapter(
                child: statsAsync.when(
                  data: (stats) => _StatsGrid(stats: stats),
                  loading: () => const _StatsGridLoading(),
                  error: (error, _) => _ErrorState(
                    error: error.toString(),
                    onRetry: () => ref.invalidate(dashboardStatsProvider),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
              sliver: SliverToBoxAdapter(
                child: statsAsync.when(
                  data: (stats) => _SystemHealthCard(stats: stats).stagger(2),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 8),
              sliver: SliverToBoxAdapter(
                child: const _QuickActions().stagger(3),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 12),
              sliver: SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'dashboard.recent_insights'.tr(),
                  subtitle: 'dashboard.insights_subtitle'.tr(),
                  actionLabel: 'dashboard.view_all'.tr(),
                  onAction: () => context.go('/insights'),
                  icon: Icons.auto_awesome_rounded,
                ).stagger(4),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              sliver: SliverToBoxAdapter(
                child: insightsAsync.when(
                  data: (insights) => _InsightsList(insights: insights),
                  loading: () => const _InsightsListLoading(),
                  error: (error, _) => _ErrorState(
                    error: error.toString(),
                    onRetry: () => ref.invalidate(recentInsightsProvider),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🌅 HERO HEADER — Premium Welcome
// ═══════════════════════════════════════════════════════════
class _HeroHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = _getUserName();
    final greeting = _getGreeting();

    return Container(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.darkAccent.withOpacity(0.15),
                  AppColors.purple.withOpacity(0.08),
                  Colors.transparent,
                ]
              : [
                  AppColors.lightAccent.withOpacity(0.12),
                  AppColors.pink.withOpacity(0.06),
                  Colors.transparent,
                ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _LogoBadge().animate().fadeIn(duration: 400.ms).scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1, 1),
                  ),
              _UserProfile(userName: userName),
            ],
          ),
          const SizedBox(height: 40),
          Text(
            greeting,
            style: (Theme.of(context).textTheme.bodyLarge ?? const TextStyle()).copyWith(
                  color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
          ).animate(delay: 100.ms).fadeIn().slideX(begin: -0.1),
          const SizedBox(height: 8),
          Text(
            userName,
            style: GoogleFonts.sora(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              letterSpacing: -1.2,
              height: 1.1,
            ),
          ).animate(delay: 200.ms).fadeIn().slideX(begin: -0.1),
          const SizedBox(height: 16),
          Text(
            'dashboard.subtitle'.tr(),
            style: (Theme.of(context).textTheme.bodyLarge ?? const TextStyle()).copyWith(
                  color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                  height: 1.5,
                ),
          ).animate(delay: 300.ms).fadeIn(),
          const SizedBox(height: 24),
          Row(children: [
            _LiveIndicator(),
            const SizedBox(width: 12),
            Text(
              _formatCurrentDate(),
              style: (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
                    color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                    fontWeight: FontWeight.w500,
                  ),
            ).animate(delay: 400.ms).fadeIn(),
          ]),
        ],
      ),
    );
  }

  String _getUserName() {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final name = user?.userMetadata?['full_name'] as String?;
      if (name != null && name.isNotEmpty) return name.split(' ').first;
      final email = user?.email ?? '';
      if (email.isNotEmpty) return email.split('@').first;
    } catch (_) {}
    return 'Strategist';
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 18) return 'Good afternoon,';
    return 'Good evening,';
  }

  String _formatCurrentDate() {
    return DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());
  }
}

// ═══════════════════════════════════════════════════════════
// 🎯 LOGO BADGE
// ═══════════════════════════════════════════════════════════
class _LogoBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkAccent.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ).animate(onPlay: (c) => c.repeat(period: 2.seconds))
         .fadeIn(duration: 800.ms).fadeOut(delay: 400.ms),
        const SizedBox(width: 8),
        const Text(
          'VELORA',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 👤 USER PROFILE
// ═══════════════════════════════════════════════════════════
class _UserProfile extends StatelessWidget {
  final String userName;
  const _UserProfile({required this.userName});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarUrl = Supabase.instance.client.auth.currentUser?.userMetadata?['avatar_url'] as String?;

    return Row(mainAxisSize: MainAxisSize.min, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(
          userName,
          style: (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          'Strategist',
          style: (Theme.of(context).textTheme.bodySmall ?? const TextStyle()).copyWith(
                color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
              ),
        ),
      ]),
      const SizedBox(width: 12),
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.darkAccent.withOpacity(0.3),
              blurRadius: 12,
            ),
          ],
        ),
        child: ClipOval(
          child: avatarUrl != null
              ? Image.network(avatarUrl, fit: BoxFit.cover)
              : Center(
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'V',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════
// 🔴 LIVE INDICATOR
// ═══════════════════════════════════════════════════════════
class _LiveIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withOpacity(0.5),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true))
       .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 1200.ms),
      const SizedBox(width: 8),
      Text(
        'LIVE',
        style: TextStyle(
          color: AppColors.success,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════
// 📊 STATS GRID
// ═══════════════════════════════════════════════════════════
class _StatsGrid extends StatelessWidget {
  final DashboardStats stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        final isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 900;

        final cards = [
          _StatCardData(
            icon: Icons.storefront_rounded,
            label: 'dashboard.competitors'.tr(),
            value: stats.totalCompetitors,
            color: AppColors.darkAccent,
            trend: '+12%',
            trendUp: true,
            sparklineData: const [2, 3, 2, 4, 3, 5, 4, 6, 5, 7],
          ),
          _StatCardData(
            icon: Icons.shopping_bag_rounded,
            label: 'dashboard.products'.tr(),
            value: stats.totalProducts,
            color: AppColors.success,
            trend: '+8%',
            trendUp: true,
            sparklineData: const [120, 132, 141, 134, 190, 230, 250, 280, 270, 290],
          ),
          _StatCardData(
            icon: Icons.auto_awesome_rounded,
            label: 'dashboard.insights'.tr(),
            value: stats.totalInsights,
            color: AppColors.warning,
            trend: '+24%',
            trendUp: true,
            sparklineData: const [1, 2, 2, 3, 4, 3, 5, 6, 5, 7],
          ),
          _StatCardData(
            icon: Icons.priority_high_rounded,
            label: 'dashboard.critical'.tr(),
            value: stats.criticalInsights,
            color: AppColors.danger,
            trend: null,
            trendUp: false,
            sparklineData: const [3, 2, 2, 1, 1, 2, 1, 1, 0, 1],
            isCritical: true,
          ),
        ];

        if (isDesktop) {
          return Row(
            children: cards.asMap().entries.map((entry) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: entry.key == 0 ? 0 : 16),
                  child: _PremiumStatCard(data: entry.value).stagger(entry.key),
                ),
              );
            }).toList(),
          );
        } else if (isTablet) {
          return Column(children: [
            Row(children: [
              Expanded(child: _PremiumStatCard(data: cards[0]).stagger(0)),
              const SizedBox(width: 16),
              Expanded(child: _PremiumStatCard(data: cards[1]).stagger(1)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _PremiumStatCard(data: cards[2]).stagger(2)),
              const SizedBox(width: 16),
              Expanded(child: _PremiumStatCard(data: cards[3]).stagger(3)),
            ]),
          ]);
        } else {
          return Column(
            children: cards.asMap().entries.map((entry) {
              return Padding(
                padding: EdgeInsets.only(top: entry.key == 0 ? 0 : 12),
                child: _PremiumStatCard(data: entry.value).stagger(entry.key),
              );
            }).toList(),
          );
        }
      },
    );
  }
}

class _StatCardData {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final String? trend;
  final bool trendUp;
  final List<int> sparklineData;
  final bool isCritical;

  const _StatCardData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.trend,
    this.trendUp = true,
    required this.sparklineData,
    this.isCritical = false,
  });
}

class _PremiumStatCard extends StatelessWidget {
  final _StatCardData data;
  const _PremiumStatCard({required this.data});

  String _compact(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 10000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Semantics(
        label: '${data.label}: ${data.value}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: data.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(data.icon, color: data.color, size: 22),
              ),
              if (data.trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (data.trendUp ? AppColors.success : AppColors.danger).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      data.trendUp ? Icons.trending_up : Icons.trending_down,
                      size: 14,
                      color: data.trendUp ? AppColors.success : AppColors.danger,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      data.trend!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: data.trendUp ? AppColors.success : AppColors.danger,
                      ),
                    ),
                  ]),
                ),
            ]),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: data.value),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
                  builder: (context, val, child) => Text(
                    _compact(val),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                      letterSpacing: -1,
                      height: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Spacer(),
                _Sparkline(data: data.sparklineData, color: data.color, width: 60, height: 28),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              data.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 📈 SPARKLINE
// ═══════════════════════════════════════════════════════════
class _Sparkline extends StatelessWidget {
  final List<int> data;
  final Color color;
  final double width;
  final double height;

  const _Sparkline({required this.data, required this.color, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _SparklinePainter(data: data, color: color),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<int> data;
  final Color color;

  _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxVal = data.reduce(math.max).toDouble();
    final minVal = data.reduce(math.min).toDouble();
    final range = maxVal - minVal == 0 ? 1.0 : maxVal - minVal;
    final path = Path();
    final stepX = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final normalizedY = (data[i] - minVal) / range;
      final y = size.height - (normalizedY * size.height * 0.8) - (size.height * 0.1);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fillPath = Path.from(path)..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final lastX = (data.length - 1) * stepX;
    final lastY = size.height - (((data.last - minVal) / range) * size.height * 0.8) - (size.height * 0.1);
    canvas.drawCircle(Offset(lastX, lastY), 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) => old.data != data || old.color != color;
}

// ═══════════════════════════════════════════════════════════
// 🏥 SYSTEM HEALTH CARD
// ═══════════════════════════════════════════════════════════
class _SystemHealthCard extends StatelessWidget {
  final DashboardStats stats;
  const _SystemHealthCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scanRate = stats.totalCompetitors == 0 ? 0.0 : (stats.totalCompetitors - stats.criticalInsights) / stats.totalCompetitors;
    final insightsScore = (stats.totalInsights / 10).clamp(0.0, 1.0);
    final healthScore = ((scanRate * 0.6 + insightsScore * 0.4) * 100).round();

    Color healthColor;
    String healthLabel;
    IconData healthIcon;
    if (healthScore >= 80) {
      healthColor = AppColors.success; healthLabel = 'Excellent'; healthIcon = Icons.verified_rounded;
    } else if (healthScore >= 60) {
      healthColor = AppColors.info; healthLabel = 'Good'; healthIcon = Icons.check_circle_rounded;
    } else if (healthScore >= 40) {
      healthColor = AppColors.warning; healthLabel = 'Fair'; healthIcon = Icons.warning_amber_rounded;
    } else {
      healthColor = AppColors.danger; healthLabel = 'Needs Attention'; healthIcon = Icons.error_outline_rounded;
    }

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        SizedBox(
          width: 56,
          height: 56,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 56,
              height: 56,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: healthScore / 100),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => CustomPaint(
                  painter: _RingPainter(progress: value, color: healthColor, strokeWidth: 4),
                ),
              ),
            ),
            Text(
              '$healthScore',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(healthIcon, color: healthColor, size: 18),
              const SizedBox(width: 6),
              Text(
                'System Health: $healthLabel',
                style: (Theme.of(context).textTheme.titleMedium ?? const TextStyle()).copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              'Your competitive intelligence system is operating at $healthScore% efficiency.',
              style: (Theme.of(context).textTheme.bodySmall ?? const TextStyle()).copyWith(
                    color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                    height: 1.4,
                  ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _RingPainter({required this.progress, required this.color, this.strokeWidth = 2});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth;
    canvas.drawCircle(
      center, radius,
      Paint()..color = color.withOpacity(0.15)..style = PaintingStyle.stroke..strokeWidth = strokeWidth,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress || old.color != color;
}

// ═══════════════════════════════════════════════════════════
// ⚡ QUICK ACTIONS
// ═══════════════════════════════════════════════════════════
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bolt_rounded, color: AppColors.warning, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            'Quick Actions',
            style: (Theme.of(context).textTheme.titleMedium ?? const TextStyle()).copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Text(
            'Shortcuts',
            style: (Theme.of(context).textTheme.bodySmall ?? const TextStyle()).copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  letterSpacing: 0.5,
                ),
          ),
        ]),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;
          final children = [
            _ActionButton(icon: Icons.add_rounded, label: 'Add Competitor', shortcut: 'N', gradient: AppColors.primaryGradient, onTap: () => context.go('/competitors/add')),
            _ActionButton(icon: Icons.radar_rounded, label: 'Run Scan', shortcut: '⌘R', gradient: AppColors.successGradient, onTap: () => context.go('/scan')),
            _ActionButton(icon: Icons.analytics_rounded, label: 'Analytics', shortcut: '⌘A', gradient: AppColors.warningGradient, onTap: () => context.go('/analytics')),
            _ActionButton(icon: Icons.sticky_note_2_rounded, label: 'Strategic Notes', shortcut: '⌘⇧N', gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)]), onTap: () => context.go('/notes')),
          ];

          if (isWide) {
            return Row(children: children.expand((e) => [Expanded(child: e), const SizedBox(width: 12)]).toList()..removeLast());
          }
          return Column(children: children.expand((e) => [e, const SizedBox(height: 12)]).toList()..removeLast());
        }),
      ]),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String shortcut;
  final Gradient gradient;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.shortcut, required this.gradient, required this.onTap});

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (h) => setState(() => _hovering = h),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovering ? AppColors.darkAccent.withOpacity(0.5) : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: 1,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(gradient: widget.gradient, borderRadius: BorderRadius.circular(10)),
              child: Icon(widget.icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                widget.label,
                style: TextStyle(color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.shortcut,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                  letterSpacing: 0.3,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 📌 SECTION HEADER
// ═══════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final IconData icon;

  const _SectionHeader({required this.title, required this.subtitle, required this.actionLabel, required this.onAction, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: AppColors.darkAccent.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            title,
            style: (Theme.of(context).textTheme.titleLarge ?? const TextStyle()).copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: (Theme.of(context).textTheme.bodySmall ?? const TextStyle()).copyWith(
                  color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                ),
          ),
        ]),
      ),
      TextButton.icon(
        onPressed: onAction,
        icon: Icon(Icons.arrow_forward_rounded, size: 16, color: isDark ? AppColors.darkAccent : AppColors.lightAccent),
        label: Text(
          actionLabel,
          style: TextStyle(color: isDark ? AppColors.darkAccent : AppColors.lightAccent, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════
// 💡 INSIGHTS LIST
// ═══════════════════════════════════════════════════════════
class _InsightsList extends StatelessWidget {
  final List<InsightPreview> insights;
  const _InsightsList({required this.insights});

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return const _EmptyInsightsState().animate().fadeIn(duration: 500.ms);
    }

    return Column(
      children: insights.asMap().entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _PremiumInsightCard(insight: entry.value)
              .animate()
              .fadeIn(duration: 500.ms, delay: Duration(milliseconds: 100 * entry.key))
              .slideX(begin: -0.05, end: 0, duration: 600.ms, delay: Duration(milliseconds: 100 * entry.key)),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 💎 PREMIUM INSIGHT CARD — AI Enhanced & Expandable (FIXED)
// ═══════════════════════════════════════════════════════════
class _PremiumInsightCard extends StatefulWidget {
  final InsightPreview insight;
  const _PremiumInsightCard({required this.insight});

  @override
  State<_PremiumInsightCard> createState() => _PremiumInsightCardState();
}

class _PremiumInsightCardState extends State<_PremiumInsightCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final severityColor = _getSeverityColor(widget.insight.severity);
    final typeIcon = _getTypeIcon(widget.insight.severity);
    
    // FIX: Safe dynamic access for aiRecommendation to avoid null errors
    final aiRec = (widget.insight as dynamic).aiRecommendation as String? ?? '';

    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: () => setState(() => _expanded = !_expanded),
      animate: false,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 4,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [severityColor, severityColor.withOpacity(0.3)],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),
            Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(typeIcon, color: severityColor, size: 22),
                ),
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6), // FIX: Solid color instead of gradient to avoid TextStyle/BoxDecoration conflicts
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withOpacity(0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      widget.insight.title,
                      style: (Theme.of(context).textTheme.titleMedium ?? const TextStyle()).copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                    ),
                  ),
                  _SeverityBadge(severity: widget.insight.severity, color: severityColor),
                ]),
                const SizedBox(height: 8),
                _FormattedText(
                  text: widget.insight.summary,
                  // FIX: Guaranteed non-null TextStyle
                  style: (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
                        color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                        height: 1.5,
                      ),
                  maxLines: _expanded ? null : 2,
                ),
                if (!_expanded) ...[
                  const SizedBox(height: 12),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 10, color: Color(0xFF8B5CF6)),
                          SizedBox(width: 4),
                          Text('AI Analysis', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF8B5CF6))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('Tap to expand', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF8B5CF6))),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 10, color: Color(0xFF8B5CF6)),
                  ]),
                ],
              ]),
            ),
            const SizedBox(width: 12),
            AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 300),
              child: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary, size: 22),
            ),
          ]),
        ),

        if (_expanded)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              const SizedBox(height: 16),
              
              // FIX: Safe null check for aiRec
              if (aiRec.isNotEmpty) ...[
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.psychology_rounded, color: Color(0xFF8B5CF6), size: 14),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Strategic Recommendation',
                    style: TextStyle(
                      color: Color(0xFF8B5CF6),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'AI GENERATED',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6), letterSpacing: 0.8),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.2), width: 1),
                  ),
                  child: _FormattedText(
                    // FIX: Passing safe non-null String
                    text: aiRec,
                    style: (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
                          height: 1.7,
                          color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                        ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              Row(children: [
                Icon(Icons.access_time_rounded, size: 14, color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary),
                const SizedBox(width: 6),
                Text(
                  _formatDate(widget.insight.createdAt),
                  style: (Theme.of(context).textTheme.bodySmall ?? const TextStyle()).copyWith(
                        color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ]),
            ]),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0),
      ]),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical': return AppColors.danger;
      case 'high': return AppColors.warning;
      case 'medium': return AppColors.info;
      case 'low': return AppColors.success;
      default: return AppColors.darkAccent;
    }
  }

  IconData _getTypeIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical': return Icons.priority_high_rounded;
      case 'high': return Icons.trending_up_rounded;
      case 'medium': return Icons.insights_rounded;
      case 'low': return Icons.lightbulb_rounded;
      default: return Icons.auto_awesome_rounded;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(date);
  }
}

// ═══════════════════════════════════════════════════════════
// 📝 FORMATTED TEXT WIDGET (Handles bullet points)
// ═══════════════════════════════════════════════════════════
class _FormattedText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final int? maxLines;

  const _FormattedText({required this.text, required this.style, this.maxLines});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    if (lines.length == 1) return Text(text, style: style, maxLines: maxLines);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.asMap().entries.map((entry) {
        final index = entry.key;
        final line = entry.value.trim();
        if (line.startsWith('-') || line.startsWith('•')) {
          final content = line.substring(1).trim();
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(color: Color(0xFF8B5CF6), shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    content,
                    style: style,
                    maxLines: maxLines != null ? maxLines! - index : null,
                  ),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(line, style: style, maxLines: maxLines != null ? maxLines! - index : null),
        );
      }).toList(),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  final String severity;
  final Color color;
  const _SeverityBadge({required this.severity, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ).animate(onPlay: (c) => c.repeat(period: 1500.ms)).fadeIn().fadeOut(delay: 750.ms),
        const SizedBox(width: 6),
        Text(
          severity.toUpperCase(),
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🕳️ EMPTY STATE
// ═══════════════════════════════════════════════════════════
class _EmptyInsightsState extends StatelessWidget {
  const _EmptyInsightsState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      padding: const EdgeInsets.all(48),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.darkAccent.withOpacity(0.15), AppColors.purple.withOpacity(0.1)]),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.auto_awesome_rounded, size: 48, color: isDark ? AppColors.darkAccent : AppColors.lightAccent),
        ).animate(onPlay: (c) => c.repeat(period: 3.seconds))
         .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 1500.ms)
         .then()
         .scale(begin: const Offset(1.05, 1.05), end: const Offset(0.95, 0.95), duration: 1500.ms),
        const SizedBox(height: 20),
        Text(
          'dashboard.no_insights'.tr(),
          style: (Theme.of(context).textTheme.titleMedium ?? const TextStyle()).copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Insights will appear here once your competitors are scanned.',
          textAlign: TextAlign.center,
          style: (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
                color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
              ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ⏳ LOADING STATES
// ═══════════════════════════════════════════════════════════
class _StatsGridLoading extends StatelessWidget {
  const _StatsGridLoading();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth > 900;
      final isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 900;
      final card = SizedBox(height: 140, child: ShimmerLoading(width: double.infinity, height: double.infinity, borderRadius: 20));

      if (isDesktop) {
        return Row(children: List.generate(4, (i) => Expanded(child: Padding(padding: EdgeInsets.only(left: i == 0 ? 0 : 16), child: card))));
      } else if (isTablet) {
        return Column(children: [
          Row(children: [Expanded(child: card), const SizedBox(width: 16), Expanded(child: card)]),
          const SizedBox(height: 16),
          Row(children: [Expanded(child: card), const SizedBox(width: 16), Expanded(child: card)]),
        ]);
      } else {
        return Column(children: List.generate(4, (i) => Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 12), child: card)));
      }
    });
  }
}

class _InsightsListLoading extends StatelessWidget {
  const _InsightsListLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (i) => Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: ShimmerLoading(width: double.infinity, height: 120, borderRadius: 20).animate(delay: Duration(milliseconds: 100 * i)).fadeIn(),
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

  _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      gradientBorder: AppColors.dangerGradient,
      padding: const EdgeInsets.all(24),
      animate: false,
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Something went wrong', style: (Theme.of(context).textTheme.titleMedium ?? const TextStyle()).copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              error,
              style: (Theme.of(context).textTheme.bodySmall ?? const TextStyle()).copyWith(color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
        const SizedBox(width: 16),
        SizedBox(
          height: 36,
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ]),
    );
  }
}
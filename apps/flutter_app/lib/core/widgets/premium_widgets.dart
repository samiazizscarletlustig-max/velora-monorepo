import 'dart:ui';

import 'package:flutter/foundation.dart'; // ✅ NEW: for kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';

import '../config/app_colors.dart';

/// ═══════════════════════════════════════════════════════════
/// 💎 VELORA PREMIUM DESIGN SYSTEM (WEB-SAFE EDITION)
/// Production-ready, accessible, high-performance components.
/// ✅ FIXED: BackdropFilter, Shimmer blend-modes and infinite
///    orb repaints are now disabled/simplified on Flutter Web
///    to prevent silent release-mode crashes (gray screen).
/// ═══════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────
// 🎴 GlassCard — Glassmorphism card with hover & gradient ring
// ─────────────────────────────────────────────────────────────
class GlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final bool animate;
  final bool hoverable;
  final bool blur;
  final VoidCallback? onTap;
  final Gradient? gradientBorder;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.animate = true,
    this.hoverable = true,
    this.blur = true,
    this.onTap,
    this.gradientBorder,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _hovered = false;

  void _setHover(bool value) {
    if (mounted && _hovered != value) setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ WEB FIX: BackdropFilter crashes / blanks Flutter Web release
    // builds. We only use real backdrop blur on native platforms.
    final bool useBlur = widget.blur && !kIsWeb;

    // ── Inner card body ──
    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: widget.padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  // ✅ WEB FIX: fully opaque on web (no translucency
                  // artifacts over the animated background)
                  AppColors.darkSurface.withOpacity(kIsWeb ? 1.0 : (_hovered ? 0.95 : 0.85)),
                  AppColors.darkSurfaceVariant.withOpacity(kIsWeb ? 0.9 : 0.65),
                ]
              : [
                  AppColors.lightSurface.withOpacity(0.98),
                  AppColors.lightSurfaceVariant.withOpacity(0.75),
                ],
        ),
        border: widget.gradientBorder == null
            ? Border.all(
                color: isDark
                    ? AppColors.darkBorder.withOpacity(_hovered ? 0.9 : 0.5)
                    : AppColors.lightBorder.withOpacity(_hovered ? 1 : 0.6),
                width: 1,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              isDark ? (_hovered ? 0.42 : 0.30) : (_hovered ? 0.12 : 0.07),
            ),
            blurRadius: _hovered ? 32 : 22,
            offset: Offset(0, _hovered ? 16 : 10),
          ),
          if (_hovered)
            BoxShadow(
              color: AppColors.darkAccent.withOpacity(0.10),
              blurRadius: 44,
            ),
        ],
      ),
      child: useBlur
          ? ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: widget.child,
              ),
            )
          : widget.child,
    );

    // ── Gradient border ring (1.5px) ──
    if (widget.gradientBorder != null) {
      card = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius + 1),
          gradient: widget.gradientBorder,
        ),
        padding: const EdgeInsets.all(1.5),
        child: card,
      );
    }

    // ── Outer margin ──
    if (widget.margin != null) {
      card = Padding(padding: widget.margin!, child: card);
    }

    // ── Interactivity (hover + tap) ──
    if (widget.onTap != null || widget.hoverable) {
      card = MouseRegion(
        onEnter: (_) => _setHover(true),
        onExit: (_) => _setHover(false),
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: widget.onTap,
          child: card,
        ),
      );
    }

    // ── Entrance animation ──
    // ✅ WEB FIX: skip flutter_animate entrance on web release to
    // avoid animation-controller exceptions during fast rebuilds.
    if (!widget.animate || kIsWeb) return card;

    return card.animate()
        .fadeIn(duration: 500.ms, curve: Curves.easeOutQuart)
        .slideY(begin: 0.08, end: 0, duration: 600.ms, curve: Curves.easeOutQuart);
  }
}

// ─────────────────────────────────────────────────────────────
// 🎨 GradientButton — Gradient CTA with press & hover physics
// ─────────────────────────────────────────────────────────────
class GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final Gradient? gradient;
  final double height;
  final double borderRadius;

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.gradient,
    this.height = 52,
    this.borderRadius = 14,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _pressScale;
  bool _hovered = false;

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pressScale,
      builder: (context, child) => Transform.scale(
        scale: _pressScale.value,
        child: child,
      ),
      child: MouseRegion(
        onEnter: (_) {
          if (_isEnabled && mounted) setState(() => _hovered = true);
        },
        onExit: (_) {
          if (mounted) setState(() => _hovered = false);
        },
        cursor: _isEnabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          onTapDown: _isEnabled ? (_) => _pressController.forward() : null,
          onTapUp: (_) => _pressController.reverse(),
          onTapCancel: _pressController.reverse,
          onTap: _isEnabled ? widget.onPressed : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: _isEnabled
                  ? (widget.gradient ?? AppColors.primaryGradient)
                  : null,
              color: _isEnabled ? null : Colors.grey.withOpacity(0.25),
              boxShadow: _isEnabled
                  ? [
                      BoxShadow(
                        color: AppColors.darkAccent
                            .withOpacity(_hovered ? 0.5 : 0.32),
                        blurRadius: _hovered ? 28 : 18,
                        offset: Offset(0, _hovered ? 10 : 7),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          widget.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 📊 AnimatedStatCard — Animated counter + trend indicator
// ─────────────────────────────────────────────────────────────
class AnimatedStatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color? color;
  final String? suffix;
  final String? trend;
  final bool trendUp;

  const AnimatedStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.suffix,
    this.trend,
    this.trendUp = true,
  });

  /// 1200 → "1.2K" | 3400000 → "3.4M"
  static String _compact(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 10000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = color ?? (isDark ? AppColors.darkAccent : AppColors.lightAccent);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Semantics(
        label: '$label: $value',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                if (trend != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: (trendUp ? AppColors.success : AppColors.danger)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          trendUp ? Icons.trending_up : Icons.trending_down,
                          size: 14,
                          color: trendUp ? AppColors.success : AppColors.danger,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          trend!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: trendUp ? AppColors.success : AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: value),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, val, child) => Text(
                '${_compact(val)}${suffix ?? ''}',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  letterSpacing: -1,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
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

// ─────────────────────────────────────────────────────────────
// ⏳ ShimmerLoading — Theme-aware skeleton placeholder
// ✅ WEB FIX: shimmer package uses blend modes that can crash
//    Flutter Web release builds → simple pulse fallback on web.
// ─────────────────────────────────────────────────────────────
class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (kIsWeb) {
      return _WebPulse(
        width: width,
        height: height,
        borderRadius: borderRadius,
        color: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade300,
      );
    }

    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade300,
      highlightColor: isDark ? AppColors.darkBorder : Colors.grey.shade100,
      period: const Duration(milliseconds: 1400),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Simple, GPU-cheap pulsing skeleton used on Flutter Web.
class _WebPulse extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color color;

  const _WebPulse({
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.color,
  });

  @override
  State<_WebPulse> createState() => _WebPulseState();
}

class _WebPulseState extends State<_WebPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 0.9).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 🏷️ PremiumChip — Animated selectable chip
// ─────────────────────────────────────────────────────────────
class PremiumChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool selected;
  final VoidCallback? onTap;

  const PremiumChip({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = color ?? (isDark ? AppColors.darkAccent : AppColors.lightAccent);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? accent.withOpacity(0.15)
                : (isDark
                    ? AppColors.darkSurfaceVariant
                    : AppColors.lightSurfaceVariant),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accent.withOpacity(0.5) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: selected
                      ? accent
                      : (isDark
                          ? AppColors.darkSecondary
                          : AppColors.lightSecondary),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? accent
                      : (isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 🌊 AnimatedGradientBackground — Living ambient orbs
// ✅ WEB FIX: on web we render STATIC orbs (no infinite
//    AnimationController repaint) — this was silently killing
//    the release build on Flutter Web.
// ─────────────────────────────────────────────────────────────
class AnimatedGradientBackground extends StatefulWidget {
  final Widget child;

  const AnimatedGradientBackground({super.key, required this.child});

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _orbController;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    );
    // ✅ WEB FIX: do NOT repeat() on web (infinite repaint crash).
    if (!kIsWeb) {
      _orbController.repeat(reverse: true);
    } else {
      _orbController.value = 0.5; // static, pleasant position
    }
  }

  @override
  void dispose() {
    _orbController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Ambient orbs (non-interactive layer)
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _orbController,
            builder: (context, _) => Stack(
              children: [
                Positioned(
                  top: -100 + (_orbController.value * 60),
                  left: -120,
                  child: _Orb(
                    size: 320,
                    color: AppColors.darkAccent,
                    opacity: isDark ? 0.22 : 0.10,
                  ),
                ),
                Positioned(
                  bottom: -120 - (_orbController.value * 60),
                  right: -120,
                  child: _Orb(
                    size: 420,
                    color: AppColors.purple,
                    opacity: isDark ? 0.18 : 0.08,
                  ),
                ),
                Positioned(
                  top: 40,
                  right: -80,
                  child: _Orb(
                    size: 200,
                    color: AppColors.pink,
                    opacity: isDark ? 0.10 : 0.05,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Actual screen content
        widget.child,
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _Orb({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(opacity), Colors.transparent],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AppAnimations {
  AppAnimations._();

  // ═══════════════════════════════════════════
  // Fade + Slide
  // ═══════════════════════════════════════════
  static List<Effect<dynamic>> fadeInUp({Duration delay = Duration.zero}) => [
        FadeEffect(
          begin: 0,
          end: 1,
          duration: 500.ms,
          delay: delay,
          curve: Curves.easeOutQuart,
        ),
        SlideEffect(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
          duration: 600.ms,
          delay: delay,
          curve: Curves.easeOutQuart,
        ),
      ];

  static List<Effect<dynamic>> fadeInDown({Duration delay = Duration.zero}) => [
        FadeEffect(
          begin: 0,
          end: 1,
          duration: 500.ms,
          delay: delay,
          curve: Curves.easeOutQuart,
        ),
        SlideEffect(
          begin: const Offset(0, -0.15),
          end: Offset.zero,
          duration: 600.ms,
          delay: delay,
          curve: Curves.easeOutQuart,
        ),
      ];

  static List<Effect<dynamic>> fadeInLeft({Duration delay = Duration.zero}) => [
        FadeEffect(
          begin: 0,
          end: 1,
          duration: 500.ms,
          delay: delay,
          curve: Curves.easeOutQuart,
        ),
        SlideEffect(
          begin: const Offset(-0.15, 0),
          end: Offset.zero,
          duration: 600.ms,
          delay: delay,
          curve: Curves.easeOutQuart,
        ),
      ];

  static List<Effect<dynamic>> fadeInRight({Duration delay = Duration.zero}) => [
        FadeEffect(
          begin: 0,
          end: 1,
          duration: 500.ms,
          delay: delay,
          curve: Curves.easeOutQuart,
        ),
        SlideEffect(
          begin: const Offset(0.15, 0),
          end: Offset.zero,
          duration: 600.ms,
          delay: delay,
          curve: Curves.easeOutQuart,
        ),
      ];

  // ═══════════════════════════════════════════
  // Scale (للبطاقات والأزرار)
  // ═══════════════════════════════════════════
  static List<Effect<dynamic>> scaleIn({Duration delay = Duration.zero}) => [
        ScaleEffect(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          duration: 400.ms,
          delay: delay,
          curve: Curves.easeOutBack,
        ),
        FadeEffect(
          begin: 0,
          end: 1,
          duration: 400.ms,
          delay: delay,
          curve: Curves.easeOut,
        ),
      ];

  // ═══════════════════════════════════════════
  // Stagger (لقائمة العناصر)
  // ═══════════════════════════════════════════
  static List<Effect<dynamic>> stagger(int index) => fadeInUp(
        delay: Duration(milliseconds: index * 80),
      );

  // ═══════════════════════════════════════════
  // Shimmer (للتحميل)
  // ═══════════════════════════════════════════
  static List<Effect<dynamic>> shimmer() => [
        const ShimmerEffect(
          duration: Duration(milliseconds: 1200),
          colors: [
            Color(0xFFEBEBF4),
            Color(0xFFD6D6E0),
            Color(0xFFEBEBF4),
          ],
        ),
      ];

  // ═══════════════════════════════════════════
  // Shake (للأخطاء/التنبيهات)
  // ═══════════════════════════════════════════
  static List<Effect<dynamic>> shake() => [
        ShakeEffect(
          duration: 500.ms,
          hz: 4,
          curve: Curves.easeInOut,
        ),
      ];
}

// ═══════════════════════════════════════════
// Page Transitions
// ═══════════════════════════════════════════
class FadeSlideRoute extends PageRouteBuilder {
  final Widget page;
  final Offset slideOffset;

  FadeSlideRoute({
    required this.page,
    this.slideOffset = const Offset(0, 0.05),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: slideOffset,
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        );
}
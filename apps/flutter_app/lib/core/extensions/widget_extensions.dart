import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../animations/animations.dart';

extension WidgetExtensions on Widget {
  // ═══════════════════════════════════════════
  // Padding Shortcuts
  // ═══════════════════════════════════════════
  Widget p(double value) =>
      Padding(padding: EdgeInsets.all(value), child: this);

  Widget px(double value) =>
      Padding(padding: EdgeInsets.symmetric(horizontal: value), child: this);

  Widget py(double value) =>
      Padding(padding: EdgeInsets.symmetric(vertical: value), child: this);

  Widget pOnly({
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) =>
      Padding(
        padding: EdgeInsets.only(
          top: top ?? 0,
          bottom: bottom ?? 0,
          left: left ?? 0,
          right: right ?? 0,
        ),
        child: this,
      );

  // ═══════════════════════════════════════════
  // Margin Shortcuts
  // ═══════════════════════════════════════════
  Widget m(double value) =>
      Container(margin: EdgeInsets.all(value), child: this);

  Widget mx(double value) =>
      Container(margin: EdgeInsets.symmetric(horizontal: value), child: this);

  Widget my(double value) =>
      Container(margin: EdgeInsets.symmetric(vertical: value), child: this);

  // ═══════════════════════════════════════════
  // Animation Shortcuts
  // ═══════════════════════════════════════════
  Widget fadeInUp({int delayMs = 0}) => animate(
        effects: AppAnimations.fadeInUp(
          delay: Duration(milliseconds: delayMs),
        ),
      );

  Widget fadeInDown({int delayMs = 0}) => animate(
        effects: AppAnimations.fadeInDown(
          delay: Duration(milliseconds: delayMs),
        ),
      );

  Widget fadeInLeft({int delayMs = 0}) => animate(
        effects: AppAnimations.fadeInLeft(
          delay: Duration(milliseconds: delayMs),
        ),
      );

  Widget fadeInRight({int delayMs = 0}) => animate(
        effects: AppAnimations.fadeInRight(
          delay: Duration(milliseconds: delayMs),
        ),
      );

  Widget scaleIn({int delayMs = 0}) => animate(
        effects: AppAnimations.scaleIn(
          delay: Duration(milliseconds: delayMs),
        ),
      );

  Widget stagger(int index) => animate(
        effects: AppAnimations.stagger(index),
      );

  // ═══════════════════════════════════════════
  // Layout Shortcuts
  // ═══════════════════════════════════════════
  Widget centered() => Center(child: this);

  Widget expanded({int flex = 1}) => Expanded(flex: flex, child: this);

  Widget flexible({int flex = 1, FlexFit fit = FlexFit.loose}) =>
      Flexible(flex: flex, fit: fit, child: this);

  // ═══════════════════════════════════════════
  // Size Shortcuts
  // ═══════════════════════════════════════════
  Widget sized({double? width, double? height}) =>
      SizedBox(width: width, height: height, child: this);

  Widget sizedSquare(double size) => SizedBox(
        width: size,
        height: size,
        child: this,
      );

  // ═══════════════════════════════════════════
  // Visibility Shortcuts
  // ═══════════════════════════════════════════
  Widget visible(bool condition) =>
      condition ? this : const SizedBox.shrink();

  Widget ifTrue(bool condition) => visible(condition);
}
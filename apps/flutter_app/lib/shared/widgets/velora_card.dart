import 'package:flutter/material.dart';

class VeloraCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const VeloraCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24.0),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
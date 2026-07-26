import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/strategy_node.dart';
import '../providers/strategy_provider.dart';

class StrategyNodeWidget extends ConsumerWidget {
  final StrategyNode node;
  final double scale;

  const StrategyNodeWidget({
    super.key,
    required this.node,
    required this.scale,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color typeColor;
    IconData typeIcon;

    switch (node.type) {
      case StrategyNodeType.pricing:
        typeColor = const Color(0xFF3B82F6); // Blue
        typeIcon = Icons.attach_money;
        break;
      case StrategyNodeType.marketing:
        typeColor = const Color(0xFF10B981); // Emerald
        typeIcon = Icons.campaign;
        break;
      case StrategyNodeType.product:
        typeColor = const Color(0xFF8B5CF6); // Purple
        typeIcon = Icons.inventory_2;
        break;
      case StrategyNodeType.distribution:
        typeColor = const Color(0xFFF59E0B); // Amber
        typeIcon = Icons.local_shipping;
        break;
      case StrategyNodeType.threat:
        typeColor = Colors.redAccent;
        typeIcon = Icons.warning_amber_rounded;
        break;
      case StrategyNodeType.opportunity:
        typeColor = Colors.greenAccent;
        typeIcon = Icons.lightbulb_outline;
        break;
    }

    if (node.colorOverride != null) {
      typeColor = node.colorOverride!;
    }

    return Positioned(
      left: node.position.dx,
      top: node.position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          // Adjust for scale
          final newPos = node.position + (details.delta / scale);
          ref.read(strategyCanvasProvider.notifier).updateNodePosition(node.id, newPos);
        },
        child: Container(
          width: 280,
          decoration: BoxDecoration(
            color: const Color(0xFF161B26).withOpacity(0.85), // Glassmorphism base
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: typeColor.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: typeColor.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      border: Border(
                        bottom: BorderSide(color: typeColor.withOpacity(0.2), width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(typeIcon, color: typeColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            node.type.name.toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: typeColor,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        Icon(Icons.drag_indicator, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3), size: 16),
                      ],
                    ),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          node.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          node.description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            height: 1.5,
                          ),
                        ),
                      ],
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

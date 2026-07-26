import 'package:flutter/material.dart';
import '../models/strategy_node.dart';
import '../models/strategy_connection.dart';

class StrategyCanvasPainter extends CustomPainter {
  final List<StrategyNode> nodes;
  final List<StrategyConnection> connections;
  final ThemeData theme;
  final bool isRtl;

  StrategyCanvasPainter({
    required this.nodes,
    required this.connections,
    required this.theme,
    required this.isRtl,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw dot grid background for that premium OS feel
    final gridPaint = Paint()
      ..color = theme.colorScheme.onSurface.withOpacity(0.05)
      ..strokeWidth = 1
      ..style = PaintingStyle.fill;
    
    const double gridSize = 40.0;
    for (double x = 0; x < size.width; x += gridSize) {
      for (double y = 0; y < size.height; y += gridSize) {
        canvas.drawCircle(Offset(x, y), 1.5, gridPaint);
      }
    }

    // Node dimensions (matching StrategyNodeWidget)
    const double nodeWidth = 280.0;
    const double nodeHeight = 160.0; // Approx

    final linePaint = Paint()
      ..color = theme.colorScheme.onSurface.withOpacity(0.3)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final arrowPaint = Paint()
      ..color = theme.colorScheme.onSurface.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    for (var conn in connections) {
      final sourceNode = nodes.cast<StrategyNode?>().firstWhere((n) => n?.id == conn.sourceNodeId, orElse: () => null);
      final targetNode = nodes.cast<StrategyNode?>().firstWhere((n) => n?.id == conn.targetNodeId, orElse: () => null);

      if (sourceNode == null || targetNode == null) continue;

      // Find closest edges
      final sourceCenter = Offset(sourceNode.position.dx + nodeWidth / 2, sourceNode.position.dy + nodeHeight / 2);
      final targetCenter = Offset(targetNode.position.dx + nodeWidth / 2, targetNode.position.dy + nodeHeight / 2);

      // Simple horizontal/vertical docking
      Offset startPoint;
      Offset endPoint;
      
      if ((sourceCenter.dx - targetCenter.dx).abs() > (sourceCenter.dy - targetCenter.dy).abs()) {
        // Connect horizontally
        if (sourceCenter.dx < targetCenter.dx) {
          startPoint = Offset(sourceNode.position.dx + nodeWidth, sourceCenter.dy);
          endPoint = Offset(targetNode.position.dx, targetCenter.dy);
        } else {
          startPoint = Offset(sourceNode.position.dx, sourceCenter.dy);
          endPoint = Offset(targetNode.position.dx + nodeWidth, targetCenter.dy);
        }
      } else {
        // Connect vertically
        if (sourceCenter.dy < targetCenter.dy) {
          startPoint = Offset(sourceCenter.dx, sourceNode.position.dy + nodeHeight);
          endPoint = Offset(targetCenter.dx, targetNode.position.dy);
        } else {
          startPoint = Offset(sourceCenter.dx, sourceNode.position.dy);
          endPoint = Offset(targetCenter.dx, targetNode.position.dy + nodeHeight);
        }
      }

      // Draw bezier curve
      final path = Path();
      path.moveTo(startPoint.dx, startPoint.dy);
      
      final double controlDistance = (startPoint - endPoint).distance * 0.4;
      
      Offset control1;
      Offset control2;
      
      if ((startPoint.dx - endPoint.dx).abs() > (startPoint.dy - endPoint.dy).abs()) {
        control1 = Offset(startPoint.dx + (startPoint.dx < endPoint.dx ? controlDistance : -controlDistance), startPoint.dy);
        control2 = Offset(endPoint.dx + (endPoint.dx < startPoint.dx ? controlDistance : -controlDistance), endPoint.dy);
      } else {
        control1 = Offset(startPoint.dx, startPoint.dy + (startPoint.dy < endPoint.dy ? controlDistance : -controlDistance));
        control2 = Offset(endPoint.dx, endPoint.dy + (endPoint.dy < startPoint.dy ? controlDistance : -controlDistance));
      }

      path.cubicTo(control1.dx, control1.dy, control2.dx, control2.dy, endPoint.dx, endPoint.dy);
      canvas.drawPath(path, linePaint);

      // Draw arrow head at endPoint
      final double arrowSize = 8.0;
      final direction = (endPoint - control2).direction;
      
      final arrowPath = Path();
      arrowPath.moveTo(endPoint.dx, endPoint.dy);
      arrowPath.lineTo(
        endPoint.dx - arrowSize * 2 * (1.0), // Need trig for perfect arrow, this is a simplified version
        endPoint.dy - arrowSize,
      );
      // Let's use proper rotation for arrow
      canvas.save();
      canvas.translate(endPoint.dx, endPoint.dy);
      canvas.rotate(direction);
      
      final properArrow = Path();
      properArrow.moveTo(0, 0);
      properArrow.lineTo(-arrowSize * 1.5, arrowSize);
      properArrow.lineTo(-arrowSize * 1.5, -arrowSize);
      properArrow.close();
      
      canvas.drawPath(properArrow, arrowPaint);
      canvas.restore();

      // Draw label if exists
      if (conn.label != null) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: conn.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              backgroundColor: theme.colorScheme.surface, // To break the line
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        )..layout();

        // Calculate mid point of bezier
        // For a cubic bezier B(t) = (1-t)^3 P0 + 3(1-t)^2 t P1 + 3(1-t) t^2 P2 + t^3 P3
        // At t=0.5:
        final midX = 0.125 * startPoint.dx + 0.375 * control1.dx + 0.375 * control2.dx + 0.125 * endPoint.dx;
        final midY = 0.125 * startPoint.dy + 0.375 * control1.dy + 0.375 * control2.dy + 0.125 * endPoint.dy;

        // Draw background for text
        final rect = Rect.fromCenter(
          center: Offset(midX, midY),
          width: textPainter.width + 16,
          height: textPainter.height + 8,
        );
        
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          Paint()..color = theme.colorScheme.surface,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          Paint()
            ..color = theme.colorScheme.onSurface.withOpacity(0.2)
            ..style = PaintingStyle.stroke,
        );

        textPainter.paint(
          canvas,
          Offset(midX - textPainter.width / 2, midY - textPainter.height / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant StrategyCanvasPainter oldDelegate) {
    return oldDelegate.nodes != nodes || 
           oldDelegate.connections != connections ||
           oldDelegate.isRtl != isRtl;
  }
}

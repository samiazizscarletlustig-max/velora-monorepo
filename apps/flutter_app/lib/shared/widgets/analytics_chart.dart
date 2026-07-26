import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:ui' as ui;

class ChartDataPoint {
  final double x;
  final double y;
  final String xLabel;
  final String yLabel;

  const ChartDataPoint({
    required this.x,
    required this.y,
    required this.xLabel,
    required this.yLabel,
  });
}

class ChartSeries {
  final List<ChartDataPoint> data;
  final Color color;
  final String name;

  const ChartSeries({
    required this.data,
    required this.color,
    required this.name,
  });
}

class AnalyticsChart extends StatefulWidget {
  final List<ChartSeries> series;
  final double height;

  const AnalyticsChart({
    super.key,
    required this.series,
    this.height = 300,
  });

  @override
  State<AnalyticsChart> createState() => _AnalyticsChartState();
}

class _AnalyticsChartState extends State<AnalyticsChart> with SingleTickerProviderStateMixin {
  Offset? _mousePosition;
  late AnimationController _enterAnimation;

  @override
  void initState() {
    super.initState();
    _enterAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void dispose() {
    _enterAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: MouseRegion(
        onHover: (event) {
          setState(() {
            _mousePosition = event.localPosition;
          });
        },
        onExit: (event) {
          setState(() {
            _mousePosition = null;
          });
        },
        child: AnimatedBuilder(
          animation: _enterAnimation,
          builder: (context, child) {
            return CustomPaint(
              painter: _ChartPainter(
                series: widget.series,
                mousePosition: _mousePosition,
                progress: CurvedAnimation(
                  parent: _enterAnimation,
                  curve: Curves.easeOutQuart,
                ).value,
                isRtl: isRtl,
                theme: Theme.of(context),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<ChartSeries> series;
  final Offset? mousePosition;
  final double progress;
  final bool isRtl;
  final ThemeData theme;

  _ChartPainter({
    required this.series,
    required this.mousePosition,
    required this.progress,
    required this.isRtl,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty || size.width == 0 || size.height == 0) return;

    final double padding = 40.0;
    final double graphWidth = size.width - (padding * 2);
    final double graphHeight = size.height - (padding * 2);

    // Determine min/max X and Y
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (var s in series) {
      for (var p in s.data) {
        if (p.x < minX) minX = p.x;
        if (p.x > maxX) maxX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.y > maxY) maxY = p.y;
      }
    }

    if (minY == maxY) {
      minY = 0;
      maxY = maxY == 0 ? 1 : maxY * 2;
    }
    if (minX == maxX) {
      minX = minX - 1;
      maxX = maxX + 1;
    }

    // Add 10% padding to Y axis top
    maxY = maxY + (maxY - minY) * 0.1;
    minY = minY > 0 ? 0 : minY; // pin to 0 if all positive

    // Draw grid lines
    final gridPaint = Paint()
      ..color = theme.colorScheme.onSurface.withOpacity(0.05)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final int yAxisSteps = 4;
    for (int i = 0; i <= yAxisSteps; i++) {
      final y = padding + graphHeight - (i / yAxisSteps) * graphHeight;
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        gridPaint,
      );

      // Y-axis label
      final labelValue = minY + (maxY - minY) * (i / yAxisSteps);
      final textPainter = TextPainter(
        text: TextSpan(
          text: labelValue.toStringAsFixed(0),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
            fontSize: 10,
          ),
        ),
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(
          isRtl ? size.width - padding + 8 : padding - textPainter.width - 8,
          y - textPainter.height / 2,
        ),
      );
    }

    // Draw series
    List<Offset> allPoints = [];
    List<ChartDataPoint> allDataPoints = [];
    
    for (var s in series) {
      if (s.data.isEmpty) continue;

      final path = Path();
      final linePaint = Paint()
        ..color = s.color
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      List<Offset> points = [];
      for (var p in s.data) {
        final xNorm = (p.x - minX) / (maxX - minX);
        final yNorm = (p.y - minY) / (maxY - minY);
        
        final xPos = isRtl 
            ? size.width - padding - (xNorm * graphWidth)
            : padding + (xNorm * graphWidth);
            
        // Apply entrance animation progress to Y
        final yPos = padding + graphHeight - (yNorm * graphHeight * progress);
        
        points.add(Offset(xPos, yPos));
        allPoints.add(Offset(xPos, yPos));
        allDataPoints.add(p);
      }

      if (points.isNotEmpty) {
        path.moveTo(points.first.dx, points.first.dy);
        
        // Draw smooth bezier curves
        for (int i = 0; i < points.length - 1; i++) {
          final p0 = points[i];
          final p1 = points[i + 1];
          final controlPointX = p0.dx + (p1.dx - p0.dx) / 2;
          
          path.cubicTo(
            controlPointX, p0.dy,
            controlPointX, p1.dy,
            p1.dx, p1.dy,
          );
        }

        canvas.drawPath(path, linePaint);

        // Draw gradient fill
        final fillPath = Path.from(path);
        fillPath.lineTo(points.last.dx, padding + graphHeight);
        fillPath.lineTo(points.first.dx, padding + graphHeight);
        fillPath.close();

        final fillPaint = Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, padding),
            Offset(0, padding + graphHeight),
            [
              s.color.withOpacity(0.3 * progress),
              s.color.withOpacity(0.0),
            ],
          )
          ..style = PaintingStyle.fill;

        canvas.drawPath(fillPath, fillPaint);
      }
    }

    // Draw Tooltip if hovered
    if (mousePosition != null && mousePosition!.dx >= padding && mousePosition!.dx <= size.width - padding) {
      // Find closest point
      double minDistance = double.infinity;
      int closestIndex = -1;
      
      for (int i = 0; i < allPoints.length; i++) {
        final dx = (allPoints[i].dx - mousePosition!.dx).abs();
        if (dx < minDistance) {
          minDistance = dx;
          closestIndex = i;
        }
      }

      if (closestIndex != -1 && minDistance < 40) {
        final point = allPoints[closestIndex];
        final dataPoint = allDataPoints[closestIndex];

        // Draw vertical indicator line (no PathDashEffect built-in for plain flutter CustomPaint without external plugins for dashed lines, so we draw a solid line with opacity)
        canvas.drawLine(
          Offset(point.dx, padding),
          Offset(point.dx, padding + graphHeight),
          Paint()
            ..color = theme.colorScheme.onSurface.withOpacity(0.2)
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke,
        );

        // Draw point dot
        canvas.drawCircle(
          point,
          6,
          Paint()..color = theme.colorScheme.surface,
        );
        canvas.drawCircle(
          point,
          4,
          Paint()..color = theme.colorScheme.primary, // Could match series color
        );

        // Draw tooltip
        final tooltipText = TextSpan(
          children: [
            TextSpan(
              text: '${dataPoint.xLabel}\n',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontSize: 10,
              ),
            ),
            TextSpan(
              text: dataPoint.yLabel,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );

        final textPainter = TextPainter(
          text: tooltipText,
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout();

        final tooltipBgRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(point.dx, point.dy - textPainter.height - 16),
            width: textPainter.width + 24,
            height: textPainter.height + 16,
          ),
          const Radius.circular(8),
        );

        // Keep tooltip inside bounds
        double shiftX = 0;
        if (tooltipBgRect.left < padding) {
          shiftX = padding - tooltipBgRect.left;
        } else if (tooltipBgRect.right > size.width - padding) {
          shiftX = size.width - padding - tooltipBgRect.right;
        }

        final shiftedRect = tooltipBgRect.shift(Offset(shiftX, 0));

        // Draw tooltip background
        canvas.drawRRect(
          shiftedRect,
          Paint()
            ..color = theme.colorScheme.surface
            ..style = PaintingStyle.fill
            ..shadows = [
              Shadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
        );
        
        canvas.drawRRect(
          shiftedRect,
          Paint()
            ..color = theme.colorScheme.onSurface.withOpacity(0.1)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );

        textPainter.paint(
          canvas,
          Offset(
            shiftedRect.center.dx - textPainter.width / 2,
            shiftedRect.center.dy - textPainter.height / 2,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.mousePosition != mousePosition || 
           oldDelegate.progress != progress ||
           oldDelegate.series != series ||
           oldDelegate.isRtl != isRtl;
  }
}

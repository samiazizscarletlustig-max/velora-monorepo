import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/strategy_provider.dart';
import 'widgets/strategy_node_widget.dart';
import 'widgets/strategy_canvas_painter.dart';

class StrategyCanvas extends ConsumerStatefulWidget {
  const StrategyCanvas({super.key});

  @override
  ConsumerState<StrategyCanvas> createState() => _StrategyCanvasState();
}

class _StrategyCanvasState extends ConsumerState<StrategyCanvas> {
  final TransformationController _transformationController = TransformationController();

  @override
  Widget build(BuildContext context) {
    final canvasState = ref.watch(strategyCanvasProvider);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A), // Deep navy/charcoal
      appBar: _buildHeader(context),
      body: Stack(
        children: [
          // Main Canvas Area
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _transformationController,
              boundaryMargin: const EdgeInsets.all(2000), // Infinite canvas feel
              minScale: 0.2,
              maxScale: 2.0,
              constrained: false, // Allows infinite panning
              onInteractionUpdate: (details) {
                // We could update scale here if needed, but InteractiveViewer handles it internally
                // We'll extract scale from the matrix to pass to nodes so drag works correctly
                final scale = _transformationController.value.getMaxScaleOnAxis();
                ref.read(strategyCanvasProvider.notifier).updateScale(scale);
              },
              child: SizedBox(
                width: 4000,
                height: 4000,
                child: Stack(
                  children: [
                    // Connections Layer (CustomPaint)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: StrategyCanvasPainter(
                          nodes: canvasState.nodes,
                          connections: canvasState.connections,
                          theme: theme,
                          isRtl: isRtl,
                        ),
                      ),
                    ),
                    
                    // Nodes Layer
                    ...canvasState.nodes.map((node) => StrategyNodeWidget(
                      node: node,
                      scale: canvasState.scale,
                    )),
                  ],
                ),
              ),
            ),
          ),
          
          // Toolbar (Bottom Center)
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: _buildToolbar(context),
            ),
          ),
          
          // Template Selector (Top Right or Left depending on RTL)
          Positioned(
            top: 24,
            right: isRtl ? null : 24,
            left: isRtl ? 24 : null,
            child: _buildTemplateSelector(context),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildHeader(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(72),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        decoration: const BoxDecoration(
          color: Color(0xFF0A0E1A),
          border: Border(
            bottom: BorderSide(color: Color(0xFF222938), width: 1),
          ),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.account_tree, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 16),
                  Text(
                    'Strategy Canvas / لوحة الاستراتيجية',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Export/Share indicator
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share Board'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF161B26),
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFF222938)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('AI Auto-Layout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26).withOpacity(0.9),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF222938), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToolButton(context, Icons.pan_tool, 'Pan', true),
          _buildToolButton(context, Icons.near_me, 'Select', false),
          const SizedBox(width: 8),
          Container(width: 1, height: 24, color: const Color(0xFF222938)),
          const SizedBox(width: 8),
          _buildAddNodeButton(context, 'Pricing', Icons.attach_money, const Color(0xFF3B82F6)),
          _buildAddNodeButton(context, 'Marketing', Icons.campaign, const Color(0xFF10B981)),
          _buildAddNodeButton(context, 'Product', Icons.inventory_2, const Color(0xFF8B5CF6)),
          _buildAddNodeButton(context, 'Distribution', Icons.local_shipping, const Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          Container(width: 1, height: 24, color: const Color(0xFF222938)),
          const SizedBox(width: 8),
          _buildToolButton(context, Icons.remove, 'Zoom Out', false),
          Text(
            '${(ref.watch(strategyCanvasProvider).scale * 100).toInt()}%',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          _buildToolButton(context, Icons.add, 'Zoom In', false),
        ],
      ),
    );
  }

  Widget _buildToolButton(BuildContext context, IconData icon, String tooltip, bool isActive) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
      onPressed: () {},
    );
  }

  Widget _buildAddNodeButton(BuildContext context, String label, IconData icon, Color color) {
    return Tooltip(
      message: 'Add $label Strategy',
      child: InkWell(
        onTap: () {
          // In a real app, this would add a node at the center of the viewport
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }

  Widget _buildTemplateSelector(BuildContext context) {
    final templates = ref.watch(strategyTemplatesProvider);
    
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: const Color(0xFF161B26).withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF222938)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              'Templates',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFF222938)),
          ...templates.map((t) => InkWell(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Icon(Icons.dashboard_customize, size: 16, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t.name,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}

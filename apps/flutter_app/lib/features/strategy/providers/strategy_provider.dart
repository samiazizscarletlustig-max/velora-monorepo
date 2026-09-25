import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/strategy_node.dart';
import '../models/strategy_connection.dart';
import '../models/strategy_template.dart';

class CanvasState {
  final List<StrategyNode> nodes;
  final List<StrategyConnection> connections;
  final Offset panOffset;
  final double scale;
  final String? activeTemplateId;

  const CanvasState({
    required this.nodes,
    required this.connections,
    this.panOffset = Offset.zero,
    this.scale = 1.0,
    this.activeTemplateId,
  });

  CanvasState copyWith({
    List<StrategyNode>? nodes,
    List<StrategyConnection>? connections,
    Offset? panOffset,
    double? scale,
    String? activeTemplateId,
  }) {
    return CanvasState(
      nodes: nodes ?? this.nodes,
      connections: connections ?? this.connections,
      panOffset: panOffset ?? this.panOffset,
      scale: scale ?? this.scale,
      activeTemplateId: activeTemplateId ?? this.activeTemplateId,
    );
  }
}

class StrategyCanvasNotifier extends Notifier<CanvasState> {
  @override
  CanvasState build() {
    // Initial mock data with bilingual text
    return const CanvasState(
      nodes: [
        StrategyNode(
          id: 'n1',
          title: '',
          description: '',
          type: StrategyNodeType.pricing,
          position: Offset(100, 150),
        ),
        StrategyNode(
          id: 'n2',
          title: '',
          description: '',
          type: StrategyNodeType.product,
          position: Offset(450, 100),
        ),
        StrategyNode(
          id: 'n3',
          title: '',
          description: '',
          type: StrategyNodeType.marketing,
          position: Offset(450, 300),
        ),
        StrategyNode(
          id: 'n4',
          title: '',
          description: '',
          type: StrategyNodeType.distribution,
          position: Offset(800, 200),
        ),
      ],
      connections: [
        StrategyConnection(id: 'c1', sourceNodeId: 'n1', targetNodeId: 'n2', label: 'Offsets margin loss'),
        StrategyConnection(id: 'c2', sourceNodeId: 'n2', targetNodeId: 'n3', label: 'Primary campaign focus'),
        StrategyConnection(id: 'c3', sourceNodeId: 'n1', targetNodeId: 'n4', label: 'Requires fast logistics'),
      ],
    );
  }

  void updateNodePosition(String id, Offset newPosition) {
    state = state.copyWith(
      nodes: state.nodes.map((node) {
        if (node.id == id) {
          return node.copyWith(position: newPosition);
        }
        return node;
      }).toList(),
    );
  }

  void updatePan(Offset delta) {
    state = state.copyWith(panOffset: state.panOffset + delta);
  }

  void updateScale(double newScale) {
    state = state.copyWith(scale: newScale.clamp(0.2, 3.0));
  }

  void addNode(StrategyNode node) {
    state = state.copyWith(nodes: [...state.nodes, node]);
  }

  void addConnection(StrategyConnection connection) {
    state = state.copyWith(connections: [...state.connections, connection]);
  }

  void applyTemplate(String templateId) {
    // Implement template applying logic here if needed
    state = state.copyWith(activeTemplateId: templateId);
  }
}

final strategyCanvasProvider = NotifierProvider<StrategyCanvasNotifier, CanvasState>(() {
  return StrategyCanvasNotifier();
});

final strategyTemplatesProvider = Provider<List<StrategyTemplate>>((ref) {
  return [
    const StrategyTemplate(
      id: 't_swot',
      name: 'SWOT Analysis',
      description: 'Strengths, Weaknesses, Opportunities, Threats mapping.',
      iconAsset: 'swot',
    ),
    const StrategyTemplate(
      id: 't_porters',
      name: "Porter's 5 Forces",
      description: 'Analyze competitive environment and industry profitability.',
      iconAsset: 'porters',
    ),
    const StrategyTemplate(
      id: 't_blue_ocean',
      name: 'Blue Ocean Canvas',
      description: 'Identify new market spaces and create new demand.',
      iconAsset: 'blue_ocean',
    ),
  ];
});

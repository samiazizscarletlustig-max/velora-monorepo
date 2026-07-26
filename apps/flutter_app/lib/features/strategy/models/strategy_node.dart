import 'package:flutter/material.dart';

enum StrategyNodeType {
  pricing,
  marketing,
  product,
  distribution,
  threat,
  opportunity,
}

class StrategyNode {
  final String id;
  final String title;
  final String description;
  final StrategyNodeType type;
  final Offset position;
  final Color? colorOverride;

  const StrategyNode({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.position,
    this.colorOverride,
  });

  StrategyNode copyWith({
    String? id,
    String? title,
    String? description,
    StrategyNodeType? type,
    Offset? position,
    Color? colorOverride,
  }) {
    return StrategyNode(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      position: position ?? this.position,
      colorOverride: colorOverride ?? this.colorOverride,
    );
  }
}

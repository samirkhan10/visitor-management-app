import 'package:flutter/material.dart';

import '../models/visitor.dart';

class VisitorAvatar extends StatelessWidget {
  const VisitorAvatar({super.key, required this.visitor, this.size = 46});

  final Visitor visitor;
  final double size;

  static const _palettes = [
    [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    [Color(0xFF0EA5E9), Color(0xFF6366F1)],
    [Color(0xFF10B981), Color(0xFF0EA5E9)],
    [Color(0xFFF59E0B), Color(0xFFEF4444)],
    [Color(0xFFEC4899), Color(0xFF8B5CF6)],
  ];

  @override
  Widget build(BuildContext context) {
    final seed = visitor.name.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    final colors = _palettes[seed % _palettes.length];

    return Hero(
      tag: 'avatar-${visitor.id}',
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.32),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Text(
            visitor.initials,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.36,
            ),
          ),
        ),
      ),
    );
  }
}

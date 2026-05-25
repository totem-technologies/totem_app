import 'package:flutter/material.dart';

class MessageAvatar extends StatelessWidget {
  const MessageAvatar({
    super.key,
    required this.color,
    this.secondary,
    this.size = 44,
  });

  final Color color;
  final Color? secondary;
  final double size;

  static const _palette = [
    Color(0xFFB6E07A),
    Color(0xFF9BC0DD),
    Color(0xFFF5E3E8),
    Color(0xFFE85A2B),
    Color(0xFF8B5CF6),
    Color(0xFFF5D76E),
    Color(0xFF76E0C2),
    Color(0xFFE07AB6),
  ];

  static Color colorFromSeed(String? seed) {
    if (seed == null || seed.isEmpty) return _palette[0];
    final hash = seed.codeUnits.fold(0, (acc, c) => acc + c);
    return _palette[hash % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: secondary != null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, secondary!],
              )
            : null,
        color: secondary == null ? color : null,
      ),
    );
  }
}

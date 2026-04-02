import 'package:flutter/material.dart';

class SmartNameText extends StatelessWidget {
  const SmartNameText({
    required this.name,
    required this.style,
    this.abbreviationThreshold = 10.0,
    this.textAlign = TextAlign.center,
    super.key,
  });
  final String name;
  final TextStyle? style;
  final double abbreviationThreshold;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fullName = name;
        final abbreviatedName = _abbreviate(fullName);

        final fullFits = _doesTextFit(
          text: fullName,
          style: (style ?? const TextStyle()).copyWith(
            fontSize: abbreviationThreshold,
          ),
          maxWidth: constraints.maxWidth,
          minFontSize: abbreviationThreshold,
        );

        final textToShow = fullFits ? fullName : abbreviatedName;

        return Text(
          textToShow.trim(),
          textAlign: textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      },
    );
  }

  // Logic to measure text
  bool _doesTextFit({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required double minFontSize,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: double.infinity);

    if (textPainter.didExceedMaxLines) {
      return false;
    }

    return textPainter.size.width <= maxWidth;
  }

  // Abbreviate name (Bruno Oliveira -> Bruno O.)
  String _abbreviate(String input) {
    final parts = input.trim().split(RegExp(r'\s+'));
    if (parts.length <= 1) return input;
    return '${parts.first} ${parts.last[0].toUpperCase()}.';
  }
}

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

class SmartNameText extends StatelessWidget {
  const SmartNameText({
    required this.name,
    required this.style,
    super.key,
    this.minFontSize = 10.0,
  });
  final String name;
  final TextStyle style;
  final double minFontSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fullName = name;
        final abbreviatedName = _abbreviate(fullName);

        final fullFits = _doesTextFit(
          text: fullName,
          style: style.copyWith(fontSize: minFontSize),
          maxWidth: constraints.maxWidth,
          minFontSize: minFontSize,
        );

        final textToShow = fullFits ? fullName : abbreviatedName;

        return AutoSizeText(
          textToShow,
          textAlign: TextAlign.center,
          maxLines: 1,
          minFontSize: minFontSize,
          overflow: TextOverflow.fade,
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

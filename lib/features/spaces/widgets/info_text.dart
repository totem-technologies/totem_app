import 'package:flutter/material.dart';
import 'package:totem_app/core/config/theme.dart';

class InfoText extends StatelessWidget {
  const InfoText(this.icon, this.text, this.subtitle, {super.key});

  final Widget icon;
  final Widget text;
  final Widget subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        IconTheme.merge(
          data: const IconThemeData(size: 24, color: AppTheme.slate),
          child: icon,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DefaultTextStyle.merge(
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppTheme.slate,
                  fontWeight: FontWeight.w600,
                ),
                child: text,
              ),
              DefaultTextStyle.merge(
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppTheme.slate,
                  fontWeight: FontWeight.w400,
                ),
                child: subtitle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CompactInfoText extends StatelessWidget {
  const CompactInfoText(this.icon, this.text, {super.key});

  final Widget icon;
  final Widget text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        IconTheme.merge(
          data: const IconThemeData(size: 14, color: Color(0xFF787D7E)),
          child: icon,
        ),
        DefaultTextStyle.merge(
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Color(0xFF787D7E),
          ),
          child: text,
        ),
      ],
    );
  }
}

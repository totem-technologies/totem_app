import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:totem_core/core/config/theme.dart';

class GroundingMarquee extends StatefulWidget {
  const GroundingMarquee({super.key});

  @override
  State<GroundingMarquee> createState() => _GroundingMarqueeState();
}

class _GroundingMarqueeState extends State<GroundingMarquee>
    with SingleTickerProviderStateMixin {
  static const messages = [
    'Now is a good time to get settled, whatever that looks like for you.',
    'We listen without interrupting and speak without being interrupted.',
    'Put on headphones if background noise is distracting.',
    'Keep your phone plugged in if your battery is low.',
    'Stretch or shift positions whenever you need to.',
    'No small talk is required here.',
    'Close any tabs or apps that might interrupt you.',
    'Your perspective matters here.',
    'Healing happens in community.',
    'Come as you are, not as you think you should be.',
    'Totem is community-led.',
    'You don’t need to calm yourself perfectly.',
    'You can turn your camera off if needed.',
    'Share what feels right.',
    'It’s always acceptable to pass.',
  ];

  /// Duration each tip is shown before transitioning to the next one.
  static const _tipDuration = Duration(seconds: 5);

  /// Duration in between the end of one tip and the start of the next.
  static const _tipDelay = Duration(seconds: 3);
  static const _fadeDuration = Duration(milliseconds: 350);

  late final AnimationController _fadeController;
  late final Animation<double> _opacity;
  int _currentIndex = Random().nextInt(messages.length);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: _fadeDuration,
      animationBehavior: AnimationBehavior.preserve,
    );
    _opacity = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _startTipsLoop();
  }

  Future<void> _startTipsLoop() async {
    while (mounted) {
      await _fadeController.forward(from: 0);
      await Future<void>.delayed(_tipDuration);
      if (!mounted) return;

      await _fadeController.reverse();
      await Future<void>.delayed(_tipDelay);
      if (!mounted) return;

      setState(() {
        _currentIndex = (_currentIndex + 1) % messages.length;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: _Tip(
        key: ValueKey('tip_$_currentIndex'),
        text: messages[_currentIndex],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsetsDirectional.symmetric(horizontal: 20),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F1E9),
          borderRadius: BorderRadius.circular(25),
          boxShadow: const [
            BoxShadow(color: Color(0xFF987AA5), blurRadius: 2),
            BoxShadow(
              color: Color(0x80F3F1E9),
              blurRadius: 11,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w300,
            color: AppTheme.black,
          ),
        ),
      ),
    );
  }
}

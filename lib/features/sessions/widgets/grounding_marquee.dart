import 'package:flutter/widgets.dart';
import 'package:totem_app/core/config/theme.dart';

class GroundingMarquee extends StatefulWidget {
  const GroundingMarquee({super.key});

  @override
  State<GroundingMarquee> createState() => _GroundingMarqueeState();
}

class _GroundingMarqueeState extends State<GroundingMarquee>
    with SingleTickerProviderStateMixin {
  static const messages = [
    'Totem is community-led.',
    'You don’t need to calm yourself perfectly.',
    'You can turn your camera off if needed.',
    'You belong.',
    'We listen without interrupting.',
    'Share what feels right.',
    'You’re allowed to arrive messy.',
    'Feeling nervous is perfectly okay.',
    'You’re allowed to take up space.',
    'It’s always acceptable to pass.',
  ];

  static const _tipDuration = Duration(milliseconds: 2500);
  static const _tipDelay = Duration(seconds: 3);
  static const _fadeDuration = Duration(milliseconds: 350);

  late final AnimationController _fadeController;
  late final Animation<double> _opacity;
  var _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: _fadeDuration);
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
      child: _Tip(text: messages[_currentIndex]),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F1E9),
          borderRadius: BorderRadius.circular(25),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF987AA5),
              blurRadius: 2,
            ),
            BoxShadow(
              color: Color(0x80F3F1E9),
              blurRadius: 11,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Text(
          text,
          maxLines: 1,
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

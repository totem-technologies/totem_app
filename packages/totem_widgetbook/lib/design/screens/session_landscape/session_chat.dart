import 'package:material_ui/material_ui.dart';

import '../../paint.dart';
import '../../pressable.dart';
import '../../tokens/tokens.dart';

/// Figma session chat, participant Everyone thread (3516:7757).
///
/// Catalog-only. The live panel still lives in `totem_core`. This copy is
/// the surface the landscape session opens: a cream column with a close
/// control, the pinned keeper-only hint, the two welcome bubbles, and
/// the Message Keeper chip over a composer.
class SessionChat extends StatefulWidget {
  const SessionChat({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<SessionChat> createState() => _SessionChatState();
}

enum _Thread { everyone, keeper }

class _Bubble {
  const _Bubble({required this.text, required this.time, this.own = false});

  final String text;
  final String time;
  final bool own;
}

class _SessionChatState extends State<SessionChat> {
  /// Everyone is the Figma default. Message Keeper flips to a private
  /// thread so the catalog can show both seats without a second story.
  var _thread = _Thread.everyone;

  final _composer = TextEditingController();
  final _focus = FocusNode();
  final _private = <_Bubble>[];

  static const _everyone = [
    _Bubble(
      text: 'Welcome! Please wait while all participants arrive.',
      time: '10:34 AM',
    ),
    _Bubble(
      text: "Please contact me in private if you're facing any issue. 😊",
      time: '10:34 AM',
    ),
  ];

  @override
  void dispose() {
    _composer.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _everyoneThread => _thread == _Thread.everyone;

  List<_Bubble> get _messages => _everyoneThread ? _everyone : _private;

  /// Participants cannot post to Everyone. They can write to the Keeper.
  bool get _canCompose => !_everyoneThread;

  void _send() {
    if (!_canCompose) return;
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _private.add(_Bubble(text: text, time: 'Now', own: true));
      _composer.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Keyboard should lift the composer, not cover it. Sheets on a
    // landscape phone are already short; this is the remaining slack.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: TotemColors.coreCream,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              title: _everyoneThread ? 'Everyone' : 'Keeper',
              onClose: widget.onClose,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.s20,
                Spacing.s16,
                Spacing.s20,
                Spacing.s12,
              ),
              child: _HintPill(
                text: _everyoneThread
                    ? 'Only the Keeper can post messages here'
                    : 'Only the keeper can see these messages',
              ),
            ),
            // The list owns the leftover height so the composer stays
            // pinned. A parent scroll view would collapse this Expanded.
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.s20,
                  0,
                  Spacing.s20,
                  Spacing.s12,
                ),
                itemCount: _messages.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, index) =>
                    _MessageBubble(message: _messages[index]),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 16, 10),
                child: _ThreadChip(
                  label: _everyoneThread
                      ? 'Message Keeper'
                      : 'View Group Messages',
                  onTap: () => setState(() {
                    _thread = _everyoneThread
                        ? _Thread.keeper
                        : _Thread.everyone;
                    _composer.clear();
                  }),
                ),
              ),
            ),
            _Composer(
              controller: _composer,
              focusNode: _focus,
              enabled: _canCompose,
              hint: _everyoneThread ? '' : 'Message Keeper',
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header — close on the leading edge, title + chevron trailing
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.s20),
        child: Row(
          children: [
            _CloseButton(onTap: onClose),
            const SizedBox(width: Spacing.s12),
            SizedBox(
              height: 28,
              child: VerticalDivider(
                width: 1,
                thickness: 1,
                color: fade(TotemColors.coreSlate, 0.12),
              ),
            ),
            const SizedBox(width: Spacing.s12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TotemText.h4.copyWith(color: TotemColors.coreSlate),
              ),
            ),
            const SizedBox(width: Spacing.s8),
            CustomPaint(
              size: const Size(12, 8),
              painter: _ChevronPainter(fade(TotemColors.coreSlate, 0.55)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.94,
      focusColor: TotemColors.coreMauve,
      focusRadius: BorderRadius.circular(Radii.full),
      semanticLabel: 'Close chat',
      builder: (context, states) {
        final hovered = states.contains(WidgetState.hovered);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: const Cubic(0.22, 1, 0.36, 1),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hovered ? fade(TotemColors.coreSlate, 0.06) : null,
            border: Border.all(color: fade(TotemColors.coreSlate, 0.28)),
          ),
          child: CustomPaint(
            size: const Size(32, 32),
            painter: const _ClosePainter(TotemColors.coreSlate),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Messages
// ---------------------------------------------------------------------------

class _HintPill extends StatelessWidget {
  const _HintPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: mix(TotemColors.coreSlate, 0.04, TotemColors.coreCream),
          borderRadius: BorderRadius.circular(Radii.full),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TotemText.caption.copyWith(
              color: TotemColors.coreGray,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _Bubble message;

  @override
  Widget build(BuildContext context) {
    final own = message.own;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: own ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth * (own ? 0.84 : 0.86),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: own
                    ? mix(TotemColors.coreMauve, 0.22, TotemColors.coreWhite)
                    : TotemColors.coreWhite,
                border: own
                    ? null
                    : Border.all(color: fade(TotemColors.coreSlate, 0.12)),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(own ? 18 : 5),
                  bottomRight: Radius.circular(own ? 4.5 : 18),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, own ? 8 : 10, 14, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      message.text,
                      style: TotemText.body.copyWith(
                        color: own
                            ? mix(
                                TotemColors.coreMauve,
                                0.55,
                                TotemColors.coreSlate,
                              )
                            : TotemColors.coreSlate,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message.time,
                      textAlign: TextAlign.end,
                      style: TotemText.caption.copyWith(
                        color: own
                            ? mix(
                                TotemColors.coreMauve,
                                0.7,
                                TotemColors.coreGray,
                              )
                            : TotemColors.coreGray,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ThreadChip extends StatelessWidget {
  const _ThreadChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.97,
      focusColor: TotemColors.coreMauve,
      focusRadius: BorderRadius.circular(Radii.full),
      semanticLabel: label,
      builder: (context, states) {
        final hovered = states.contains(WidgetState.hovered);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: hovered
                ? mix(TotemColors.coreSlate, 0.1, TotemColors.coreMauve)
                : TotemColors.coreMauve,
            borderRadius: BorderRadius.circular(Radii.full),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.25),
                offset: Offset(2, 2),
                blurRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Text(
              label,
              style: TotemText.captionBold.copyWith(
                color: TotemColors.coreWhite,
                height: 1.2,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Composer — cream pill + mauve send, matching 3516:7757
// ---------------------------------------------------------------------------

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.hint,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String hint;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: enabled ? (_) => onSend() : null,
              style: TotemText.bodySmall.copyWith(
                color: TotemColors.coreSlate,
                fontSize: 14.5,
              ),
              cursorColor: TotemColors.coreMauve,
              decoration: InputDecoration(
                hintText: hint.isEmpty ? null : hint,
                hintStyle: TotemText.bodySmall.copyWith(
                  color: TotemColors.coreGray,
                  fontSize: 14.5,
                ),
                filled: true,
                fillColor: TotemColors.coreWhite,
                isDense: true,
                contentPadding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(
                    color: fade(TotemColors.coreSlate, 0.12),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(
                    color: fade(TotemColors.coreSlate, 0.12),
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(
                    color: fade(TotemColors.coreSlate, 0.12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Pressable(
            onTap: enabled ? onSend : () {},
            pressedScale: 0.94,
            focusColor: TotemColors.coreMauve,
            focusRadius: BorderRadius.circular(Radii.full),
            semanticLabel: 'Send',
            builder: (context, states) {
              final hovered = states.contains(WidgetState.hovered);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hovered
                      ? mix(TotemColors.coreSlate, 0.1, TotemColors.coreMauve)
                      : TotemColors.coreMauve,
                ),
                child: CustomPaint(
                  size: const Size(44, 44),
                  painter: const _SendPainter(TotemColors.coreWhite),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ClosePainter extends CustomPainter {
  const _ClosePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6;
    const inset = 10.0;
    canvas.drawLine(
      Offset(inset, inset),
      Offset(size.width - inset, size.height - inset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ClosePainter oldDelegate) => oldDelegate.color != color;
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.6;
    canvas.drawPath(
      Path()
        ..moveTo(1, 1.5)
        ..lineTo(size.width / 2, size.height - 1.5)
        ..lineTo(size.width - 1, 1.5),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => oldDelegate.color != color;
}

class _SendPainter extends CustomPainter {
  const _SendPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.7;
    final path = Path()
      ..moveTo(size.width * 0.30, size.height * 0.28)
      ..lineTo(size.width * 0.72, size.height * 0.50)
      ..lineTo(size.width * 0.30, size.height * 0.72)
      ..lineTo(size.width * 0.36, size.height * 0.50)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SendPainter oldDelegate) => oldDelegate.color != color;
}

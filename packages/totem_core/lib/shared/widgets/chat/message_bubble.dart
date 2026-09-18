import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Sent / received bubble used by DMs and in-call session chat.
///
/// Own messages use the mauve fill + tail on the trailing corner; received
/// messages use a bordered cream card with the tail on the leading corner.
class MessageBubble extends StatefulWidget {
  const MessageBubble({
    required this.text,
    required this.timestamp,
    required this.isOwn,
    super.key,
  });

  final String text;
  final String timestamp;
  final bool isOwn;

  static const double _ownMaxWidthFactor = 0.84;
  static const double _receivedMaxWidthFactor = 0.86;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  static final _actionPattern = RegExp(
    r'https?://[^\s<]+|[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}|(?:\+?\d[\d\s().-]{5,}\d)',
    caseSensitive: false,
  );
  static final _trailingPunctuation = RegExp(r'[.,!?;:]+$');

  late List<_MessageAction> _actions;
  late List<TapGestureRecognizer> _recognizers;

  @override
  void initState() {
    super.initState();
    _createRecognizers();
  }

  @override
  void didUpdateWidget(covariant MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text == widget.text) return;
    _disposeRecognizers();
    _createRecognizers();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _createRecognizers() {
    _actions = _actionsFor(widget.text);
    _recognizers = [
      for (final action in _actions)
        TapGestureRecognizer()..onTap = () => unawaited(launchUrl(action.uri)),
    ];
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
  }

  List<_MessageAction> _actionsFor(String text) {
    return [
      for (final match in _actionPattern.allMatches(text)) ?_actionFor(match),
    ];
  }

  _MessageAction? _actionFor(RegExpMatch match) {
    final rawText = match.group(0)!;
    final displayText = rawText.replaceFirst(_trailingPunctuation, '');
    if (displayText.isEmpty) return null;

    final uri = switch (displayText) {
      final value
          when RegExp('https?://', caseSensitive: false).hasMatch(value) =>
        Uri.tryParse(value),
      final value when value.contains('@') => Uri(
        scheme: 'mailto',
        path: value,
      ),
      final value => _phoneUri(value),
    };
    if (uri == null ||
        (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isEmpty) {
      return null;
    }

    return _MessageAction(start: match.start, text: displayText, uri: uri);
  }

  Uri? _phoneUri(String value) {
    final number = value.replaceAll(RegExp(r'[^+\d]'), '');
    final digitCount = number.replaceAll('+', '').length;
    return digitCount >= 7 ? Uri.parse('tel:$number') : null;
  }

  List<InlineSpan> _messageSpans() {
    final messageStyle = TextStyle(
      color: widget.isOwn ? AppTheme.messagePurpleText : AppTheme.slate,
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w400,
    );
    final linkColor = widget.isOwn ? AppTheme.messagePurple : AppTheme.mauve;
    final linkStyle = messageStyle.copyWith(
      color: linkColor,
      decoration: TextDecoration.underline,
      decorationColor: linkColor,
    );
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (var index = 0; index < _actions.length; index++) {
      final action = _actions[index];
      if (action.start > cursor) {
        spans.add(
          TextSpan(
            text: widget.text.substring(cursor, action.start),
            style: messageStyle,
          ),
        );
      }
      spans.add(
        TextSpan(
          text: action.text,
          style: linkStyle,
          // TODO(totem): Use LinkSpan when available
          // https://github.com/flutter/flutter/issues/91600
          recognizer: _recognizers[index],
        ),
      );
      cursor = action.start + action.text.length;
    }

    if (cursor < widget.text.length) {
      spans.add(
        TextSpan(text: widget.text.substring(cursor), style: messageStyle),
      );
    }
    return spans.isEmpty
        ? [TextSpan(text: widget.text, style: messageStyle)]
        : spans;
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.isOwn
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxBubbleWidth =
              constraints.maxWidth *
              (widget.isOwn
                  ? MessageBubble._ownMaxWidthFactor
                  : MessageBubble._receivedMaxWidthFactor);

          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: IntrinsicWidth(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.isOwn
                      ? AppTheme.messagePurpleBg
                      : AppTheme.surfaceCard,
                  border: widget.isOwn
                      ? null
                      : Border.all(color: AppTheme.divider, width: 1),
                  borderRadius: widget.isOwn
                      ? const BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(18),
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(4.5),
                        )
                      : const BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                          bottomLeft: Radius.circular(5),
                        ),
                ),
                child: Padding(
                  padding: EdgeInsetsDirectional.symmetric(
                    horizontal: 14,
                    vertical: widget.isOwn ? 4.5 : 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text.rich(
                        TextSpan(children: _messageSpans()),
                        textWidthBasis: TextWidthBasis.longestLine,
                      ),
                      SizedBox(height: widget.isOwn ? 11 : 5),
                      Text(
                        widget.timestamp,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: widget.isOwn
                              ? AppTheme.messagePurple
                              : AppTheme.textMuted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MessageAction {
  const _MessageAction({
    required this.start,
    required this.text,
    required this.uri,
  });

  final int start;
  final String text;
  final Uri uri;
}

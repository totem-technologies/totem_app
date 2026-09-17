import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/shared/totem_icons.dart';

/// Pill composer + circular send button shared by DMs and session chat.
class MessageInputBar extends StatefulWidget {
  const MessageInputBar({
    super.key,
    this.onSend,
    this.hintText = 'Type a message...',
    this.enabled = true,
    this.autofocus = false,
  });

  /// Returns false when the message was rejected, in which case the composer
  /// keeps the text so the user can retry instead of losing it.
  final FutureOr<bool> Function(String text)? onSend;

  /// Placeholder inside the pill field. Session chat swaps this per thread.
  final String hintText;

  /// When false the field stays visible but cannot send — used for the
  /// read-only participant Everyone thread.
  final bool enabled;

  final bool autofocus;

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  var _isSubmitting = false;

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!widget.enabled || _isSubmitting) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final onSend = widget.onSend;
    if (onSend == null) return;

    setState(() => _isSubmitting = true);
    try {
      final accepted = await onSend(text);
      if (!mounted || !accepted) return;
      _controller.clear();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceCard,
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  maxLines: 1,
                  textInputAction: TextInputAction.send,
                  onEditingComplete: _focusNode.requestFocus,
                  onFieldSubmitted: (_) => unawaited(_submit()),
                  style: const TextStyle(
                    color: AppTheme.textHeading,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                    ),
                    filled: true,
                    fillColor: AppTheme.messageInputFill,
                    contentPadding: const EdgeInsetsDirectional.fromSTEB(
                      20,
                      12,
                      16,
                      12,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: const BorderSide(color: AppTheme.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: const BorderSide(color: AppTheme.divider),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: const BorderSide(color: AppTheme.divider),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SendButton(
                controller: _controller,
                enabled: widget.enabled,
                isSubmitting: _isSubmitting,
                onSubmit: () => unawaited(_submit()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatefulWidget {
  const _SendButton({
    required this.controller,
    required this.onSubmit,
    required this.enabled,
    required this.isSubmitting,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool enabled;
  final bool isSubmitting;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant _SendButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onTextChanged);
    widget.controller.addListener(_onTextChanged);
    _onTextChanged();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  @override
  Widget build(BuildContext context) {
    final canSend = widget.enabled && !widget.isSubmitting && _hasText;
    return Semantics(
      button: true,
      enabled: canSend,
      label: 'Send',
      child: Tooltip(
        message: 'Send',
        child: GestureDetector(
          onTap: canSend ? widget.onSubmit : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: canSend ? AppTheme.mauve : AppTheme.messageGray,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const TotemIcon(
              TotemIcons.sendMessage,
              color: AppTheme.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

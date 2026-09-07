import 'package:flutter/material.dart';
import 'package:totem_core/core/config/theme.dart';

/// Pill composer + circular send button shared by DMs and session chat.
class MessageInputBar extends StatefulWidget {
  const MessageInputBar({
    super.key,
    this.onSend,
    this.hintText = 'Type a message...',
    this.enabled = true,
    this.autofocus = false,
  });

  final ValueChanged<String>? onSend;

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!widget.enabled) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend?.call(text);
    _controller.clear();
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
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  maxLines: 1,
                  textInputAction: TextInputAction.send,
                  onFieldSubmitted: (_) => _submit(),
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
                onSubmit: _submit,
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
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool enabled;

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
    final canSend = widget.enabled && _hasText;
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
            child: const Icon(
              Icons.arrow_forward_rounded,
              color: AppTheme.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

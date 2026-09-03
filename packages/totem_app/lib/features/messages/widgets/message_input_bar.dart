import 'package:flutter/material.dart';
import 'package:totem_core/core/config/theme.dart';

class MessageInputBar extends StatefulWidget {
  const MessageInputBar({super.key, this.onSend});

  final ValueChanged<String>? onSend;

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
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend?.call(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  maxLines: 1,
                  textInputAction: TextInputAction.send,
                  onFieldSubmitted: (_) => _submit(),
                  style: const TextStyle(
                    color: AppTheme.textHeading,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
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
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SendButton(controller: _controller, onSubmit: _submit),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatefulWidget {
  const _SendButton({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final VoidCallback onSubmit;

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
    return GestureDetector(
      onTap: _hasText ? widget.onSubmit : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: _hasText ? AppTheme.mauve : AppTheme.messageGray,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.arrow_forward_rounded,
          color: AppTheme.white,
          size: 22,
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';

class MessageInputBar extends StatefulWidget {
  const MessageInputBar({
    super.key,
    required this.onSend,
    required this.isSending,
  });

  final Future<bool> Function(String text) onSend;
  final bool isSending;

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

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isSending) return;
    if (await widget.onSend(text) && mounted) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.isSending;
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
                  enabled: enabled,
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
              _SendButton(
                controller: _controller,
                isSending: widget.isSending,
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
    required this.isSending,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isSending;
  final Future<void> Function() onSubmit;

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
    final enabled = _hasText && !widget.isSending;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.isSending ? 'Sending message' : 'Send message',
      child: GestureDetector(
        onTap: enabled ? widget.onSubmit : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: enabled ? AppTheme.mauve : AppTheme.messageGray,
            shape: BoxShape.circle,
          ),
          child: widget.isSending
              ? const Padding(
                  padding: EdgeInsets.all(13),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.white,
                  ),
                )
              : const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppTheme.white,
                  size: 22,
                ),
        ),
      ),
    );
  }
}

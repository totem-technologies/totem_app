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
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

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
        color: Color(0xFFFAFAF7),
        border: Border(top: BorderSide(color: Color(0xFFE8E5E0))),
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
                    color: Color(0xFF1F293B),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF8C8A82),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F0),
                    contentPadding: const EdgeInsetsDirectional.fromSTEB(
                      20,
                      12,
                      16,
                      12,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: const BorderSide(color: Color(0xFFE8E5E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: const BorderSide(color: Color(0xFFE8E5E0)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _hasText ? _submit : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: _hasText ? AppTheme.mauve : const Color(0xFFD0CDCA),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

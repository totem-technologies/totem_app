import 'package:flutter/material.dart';

class EmojiBar extends StatelessWidget {
  const EmojiBar({
    required this.emojis,
    required this.onEmojiSelected,
    super.key,
  });

  final List<String> emojis;
  final ValueChanged<String> onEmojiSelected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 15,
              vertical: 6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 10,
              children: emojis.map((emoji) {
                return GestureDetector(
                  onTap: () => onEmojiSelected(emoji),
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

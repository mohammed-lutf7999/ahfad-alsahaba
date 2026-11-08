import 'package:flutter/material.dart';

/// شريط التفاعلات والإيموجي التنافسي المباشر
class GameReactionsRibbon extends StatelessWidget {
  final ValueChanged<String> onReactionSelected;

  const GameReactionsRibbon({
    super.key,
    required this.onReactionSelected,
  });

  @override
  Widget build(BuildContext context) {
    const emojis = ['🔥', '👏', '🎯', '🤝', '😂'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: emojis.map((emoji) {
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onReactionSelected(emoji),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

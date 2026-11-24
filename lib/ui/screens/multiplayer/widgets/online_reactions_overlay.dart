import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';

/// Floating overlay layer rendering incoming chivalric quick phrases & animated emoji reactions.
class OnlineReactionsOverlay extends StatelessWidget {
  const OnlineReactionsOverlay({
    super.key,
    required this.incomingQuickPhrase,
    required this.incomingReactionEmoji,
    required this.emojiSlideAnim,
    required this.emojiFadeAnim,
  });

  final String? incomingQuickPhrase;
  final String? incomingReactionEmoji;
  final Animation<Offset> emojiSlideAnim;
  final Animation<double> emojiFadeAnim;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (incomingQuickPhrase != null)
          Positioned(
            top: 66,
            left: 16,
            right: 76,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryDark.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.accentColor.withValues(alpha: 0.7),
                ),
              ),
              child: Text(
                incomingQuickPhrase!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        if (incomingReactionEmoji != null)
          Positioned(
            top: 65,
            right: 20,
            child: SlideTransition(
              position: emojiSlideAnim,
              child: FadeTransition(
                opacity: emojiFadeAnim,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.amberAccent.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    incomingReactionEmoji!,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

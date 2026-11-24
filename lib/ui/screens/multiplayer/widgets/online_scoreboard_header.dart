import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import '../../../widgets/animated_avatar_frame.dart';
import '../../../widgets/avatar_selector.dart';

/// Top scoreboard + central countdown timer + animated progress bar for online matches.
class OnlineScoreboardHeader extends StatelessWidget {
  const OnlineScoreboardHeader({
    super.key,
    required this.myName,
    required this.myAvatarIndex,
    required this.myEquippedFrame,
    required this.myWinStreak,
    required this.myScore,
    required this.opponentName,
    required this.opponentAvatarIndex,
    required this.opponentScore,
    required this.opponentQuestionIndex,
    required this.currentQuestionIndex,
    required this.totalQuestions,
    required this.timeLeft,
    required this.progressAnimation,
  });

  final String myName;
  final int myAvatarIndex;
  final String myEquippedFrame;
  final int myWinStreak;
  final int myScore;
  final String opponentName;
  final int opponentAvatarIndex;
  final int opponentScore;
  final int opponentQuestionIndex;
  final int currentQuestionIndex;
  final int totalQuestions;
  final int timeLeft;
  final Animation<double> progressAnimation;

  @override
  Widget build(BuildContext context) {
    final isUrgent = timeLeft <= 5;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: Colors.black26,
          child: Row(
            children: [
              // Me
              Expanded(
                child: Row(
                  children: [
                    AnimatedAvatarFrame(
                      size: 42,
                      frameKey: myEquippedFrame,
                      winStreak: myWinStreak,
                      child: ProfileAvatar(avatarIndex: myAvatarIndex, size: 34),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            myName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              fontFamily: 'Cairo',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '$myScore',
                            style: const TextStyle(
                              color: AppTheme.accentColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Central Timer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isUrgent
                            ? Colors.red.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isUrgent ? Colors.red : Colors.white30,
                        ),
                      ),
                      child: Text(
                        '$timeLeft',
                        style: TextStyle(
                          color: isUrgent ? Colors.red : Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'سؤال ${currentQuestionIndex + 1}/$totalQuestions',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),

              // Opponent
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            opponentName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              fontFamily: 'Cairo',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                          Text(
                            '$opponentScore',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(
                            width: 50,
                            height: 3,
                            child: LinearProgressIndicator(
                              value: totalQuestions > 0
                                  ? (opponentQuestionIndex / totalQuestions)
                                  : 0,
                              backgroundColor: Colors.white10,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    ProfileAvatar(avatarIndex: opponentAvatarIndex, size: 36),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        AnimatedBuilder(
          animation: progressAnimation,
          builder: (context, child) {
            return LinearProgressIndicator(
              value: 1 - progressAnimation.value,
              backgroundColor: Colors.white10,
              color: isUrgent ? Colors.red : AppTheme.accentColor,
              minHeight: 4,
            );
          },
        ),
      ],
    );
  }
}

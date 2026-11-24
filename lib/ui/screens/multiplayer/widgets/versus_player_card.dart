import 'package:flutter/material.dart';

import '../../../../data/models/arena_model.dart';
import '../../../../data/models/player_level_model.dart';
import '../../../widgets/animated_avatar_frame.dart';
import '../../../widgets/avatar_selector.dart';
import '../../../widgets/level_badge_widget.dart';

/// Displays one player's half (Me or Opponent) on [VersusScreen] with ready/waiting status.
class VersusPlayerCard extends StatelessWidget {
  const VersusPlayerCard({
    super.key,
    required this.tintColor,
    required this.name,
    required this.avatarIndex,
    required this.frameKey,
    required this.winStreak,
    required this.levelInfo,
    required this.arena,
    required this.score,
    required this.trophies,
    this.customTitle,
    this.isLoading = false,
    this.isReady = true,
    this.isWaiting = false,
  });

  final Color tintColor;
  final String name;
  final int avatarIndex;
  final String frameKey;
  final int winStreak;
  final PlayerLevelInfo levelInfo;
  final ArenaModel arena;
  final int score;
  final int trophies;
  final String? customTitle;
  final bool isLoading;
  final bool isReady;
  final bool isWaiting;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: tintColor.withValues(alpha: 0.08),
      child: Center(
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedAvatarFrame(
                      size: 88,
                      frameKey: frameKey,
                      winStreak: winStreak,
                      child: ProfileAvatar(avatarIndex: avatarIndex, size: 76),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    LevelBadgeWidget(
                      levelInfo: levelInfo,
                      customTitle: customTitle,
                      isCompact: true,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'النقاط: $score  •  🏆 $trophies (${arena.name})',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (isWaiting && !isReady)
                      _buildStatusBadge(
                        color: Colors.orange,
                        leading: const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.orange,
                          ),
                        ),
                        label: 'في الانتظار...',
                      )
                    else if (isReady)
                      _buildStatusBadge(
                        color: Colors.green,
                        leading: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16,
                        ),
                        label: 'جاهز',
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatusBadge({
    required Color color,
    required Widget leading,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontFamily: 'Cairo')),
        ],
      ),
    );
  }
}

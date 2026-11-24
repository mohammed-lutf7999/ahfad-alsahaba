import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import '../../../widgets/animated_avatar_frame.dart';
import '../../../widgets/avatar_selector.dart';

/// Host vs Guest matchup visualizer row for [PrivateRoomLobbyScreen].
class PrivateRoomMatchupRow extends StatelessWidget {
  const PrivateRoomMatchupRow({
    super.key,
    required this.hostName,
    required this.hostAvatarIndex,
    required this.hostFrameKey,
    required this.guestJoined,
    required this.guestData,
    required this.startCountdown,
    required this.pulseAnimation,
  });

  final String hostName;
  final int hostAvatarIndex;
  final String hostFrameKey;
  final bool guestJoined;
  final Map<String, dynamic>? guestData;
  final int startCountdown;
  final Animation<double> pulseAnimation;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildPlayerSlot(
            name: hostName,
            avatarIndex: hostAvatarIndex,
            frameKey: hostFrameKey,
            borderColor: Colors.greenAccent.withValues(alpha: 0.4),
            badgeText: '👑 المضيف (جاهز)',
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: guestJoined
              ? Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accentColor,
                  ),
                  child: Center(
                    child: Text(
                      '$startCountdown',
                      style: const TextStyle(
                        color: AppTheme.primaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                )
              : Text(
                  'VS',
                  style: TextStyle(
                    color: AppTheme.accentColor.withValues(alpha: 0.8),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
        ),
        Expanded(
          child: guestJoined
              ? _buildPlayerSlot(
                  name: guestData?['display_name'] ??
                      guestData?['name'] ??
                      'الفارس الضيف',
                  avatarIndex:
                      (guestData?['avatar_index'] as num?)?.toInt() ?? 0,
                  frameKey: guestData?['equipped_frame'] ?? 'frame_bronze',
                  borderColor: AppTheme.accentColor.withValues(alpha: 0.6),
                  badgeText: '⚔️ انضم للنزال!',
                )
              : _buildWaitingSlot(),
        ),
      ],
    );
  }

  Widget _buildPlayerSlot({
    required String name,
    required int avatarIndex,
    required String frameKey,
    required Color borderColor,
    required String badgeText,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          AnimatedAvatarFrame(
            size: 56,
            frameKey: frameKey,
            child: ProfileAvatar(avatarIndex: avatarIndex, size: 46),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: 'Cairo',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badgeText,
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingSlot() {
    return ScaleTransition(
      scale: pulseAnimation,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.accentColor.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.accentColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'بانتظار الصديق..',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'شارك الكود معه',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

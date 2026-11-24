import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../data/models/challenge_config.dart';
import '../../../widgets/avatar_selector.dart';

class WaitingRoomChallengeInfo extends StatelessWidget {
  final ChallengeConfig config;

  const WaitingRoomChallengeInfo({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: _InfoItem(
              icon: config.type == ChallengeType.bruteForce ? '🎲' : '📚',
              label: config.type == ChallengeType.bruteForce
                  ? 'القوة الغاشمة'
                  : 'قسم محدد',
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          Expanded(
            child: _InfoItem(
              icon: '❓',
              label: '${config.questionCount} سؤال',
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          Expanded(
            child: _InfoItem(
              icon: '⚡',
              label: config.speedMode ? 'سرعة' : 'عادي',
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String icon;
  final String label;

  const _InfoItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WaitingRoomPlayersGrid extends StatelessWidget {
  final List players;
  final int maxPlayers;
  final Animation<double> pulseAnimation;

  const WaitingRoomPlayersGrid({
    super.key,
    required this.players,
    required this.maxPlayers,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 206,
      ),
      itemCount: maxPlayers,
      itemBuilder: (context, index) {
        if (index < players.length) {
          return _WaitingRoomPlayerCard(
            player: players[index],
            isHost: index == 0,
          );
        }
        return _WaitingRoomEmptySlot(pulseAnimation: pulseAnimation);
      },
    );
  }
}

class _WaitingRoomPlayerCard extends StatelessWidget {
  final dynamic player;
  final bool isHost;

  const _WaitingRoomPlayerCard({required this.player, required this.isHost});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            (isHost ? AppTheme.accentColor : Colors.white)
                .withValues(alpha: 0.15),
            (isHost ? AppTheme.accentColor : Colors.white)
                .withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isHost ? AppTheme.accentColor : Colors.white)
              .withValues(alpha: 0.3),
          width: isHost ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isHost) const Text('👑', style: TextStyle(fontSize: 24)),
          ProfileAvatar(avatarIndex: player.avatarIndex, size: 60),
          const SizedBox(height: 8),
          Text(
            player.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: player.isReady
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              player.isReady ? 'جاهز ✓' : 'ينتظر...',
              style: TextStyle(
                fontSize: 10,
                color: player.isReady ? Colors.green : Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingRoomEmptySlot extends StatelessWidget {
  final Animation<double> pulseAnimation;

  const _WaitingRoomEmptySlot({required this.pulseAnimation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03 * pulseAnimation.value),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_add_rounded,
                size: 40,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 8),
              Text(
                'في انتظار لاعب...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

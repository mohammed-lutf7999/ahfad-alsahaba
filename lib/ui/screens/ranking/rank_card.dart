import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../data/models/arena_model.dart';
import '../../../data/models/leaderboard_model.dart';
import '../../../data/models/player_level_model.dart';
import '../../widgets/animated_avatar_frame.dart';
import '../../widgets/level_badge_widget.dart';

class GlobalRankCard extends StatelessWidget {
  final RankEntry entry;
  final int index;

  const GlobalRankCard({
    super.key,
    required this.entry,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final isTop3 = entry.rank <= 3;
    final rankColor = _getRankColor(entry.rank);
    final glowColor = entry.isMe ? Colors.green : rankColor;

    final levelInfo = PlayerLevelInfo.fromTotalScore(entry.score);
    final arena = ArenaModel.fromTrophies(entry.trophies);
    final String effectiveFrameKey =
        (entry.equippedFrame.isNotEmpty && entry.equippedFrame != 'frame_wood')
            ? entry.equippedFrame
            : (entry.rank == 1 && levelInfo.level < 31
                ? 'frame_gold'
                : levelInfo.frameKey);
    final String avatarLetter =
        entry.name.trim().isNotEmpty ? entry.name.trim()[0] : 'ف';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: entry.isMe ? const Color(0xFF1E3A1E) : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: entry.isMe
              ? Colors.green.withValues(alpha: 0.5)
              : (isTop3 ? rankColor.withValues(alpha: 0.4) : Colors.white12),
          width: (entry.isMe || isTop3) ? 1.8 : 1,
        ),
        boxShadow: [
          if (isTop3 || entry.isMe)
            BoxShadow(
              color: glowColor.withValues(alpha: 0.2),
              blurRadius: 15,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isTop3
                  ? rankColor.withValues(alpha: 0.2)
                  : Colors.transparent,
              border: isTop3 ? Border.all(color: rankColor) : null,
            ),
            child: Center(
              child: isTop3
                  ? Icon(Icons.emoji_events_rounded, color: rankColor, size: 22)
                  : Text(
                      '${entry.rank}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedAvatarFrame(
            size: 48,
            frameKey: effectiveFrameKey,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF263238),
              child: Text(
                avatarLetter,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.name,
                        style: TextStyle(
                          color: entry.isMe ? Colors.greenAccent : Colors.white,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!entry.isMe && entry.countryCode.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        entry.countryCode,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    LevelBadgeWidget(
                      levelInfo: levelInfo,
                      isCompact: true,
                      customTitle: entry.playerTitle.isNotEmpty
                          ? entry.playerTitle
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: arena.accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: arena.accentColor.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        '${arena.name} • 🏆 ${entry.trophies}',
                        style: TextStyle(
                          color: arena.accentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFFFD700),
                  size: 15,
                ),
                const SizedBox(width: 4),
                Text(
                  '${entry.score}',
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700);
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return Colors.white;
    }
  }
}

class RankingStarfieldBackground extends StatefulWidget {
  const RankingStarfieldBackground({super.key});

  @override
  State<RankingStarfieldBackground> createState() =>
      _RankingStarfieldBackgroundState();
}

class _RankingStarfieldBackgroundState extends State<RankingStarfieldBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StarPainter(_controller));
  }
}

class _StarPainter extends CustomPainter {
  final Animation<double> animation;

  _StarPainter(this.animation) : super(repaint: animation);

  final List<Offset> _stars = List.generate(
    40,
    (index) => Offset(
      math.Random(index).nextDouble(),
      math.Random(index).nextDouble(),
    ),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.2);
    for (int i = 0; i < _stars.length; i++) {
      final offset = _stars[i];
      final dy = (offset.dy + animation.value * 0.1) % 1.0;
      canvas.drawCircle(
        Offset(offset.dx * size.width, dy * size.height),
        1.5,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

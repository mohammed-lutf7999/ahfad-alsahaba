import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../data/models/multiplayer_player.dart';
import 'avatar_selector.dart';

class ResultCard extends StatefulWidget {
  final MultiplayerPlayer player;
  final int rank;
  final int totalQuestions;
  final bool isLocalPlayer;
  final bool isWinner;

  const ResultCard({
    super.key,
    required this.player,
    required this.rank,
    required this.totalQuestions,
    this.isLocalPlayer = false,
    this.isWinner = false,
  });

  @override
  State<ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<ResultCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isWinner) {
      return _build3DWinnerCard();
    }
    return _buildRankedCard();
  }

  Widget _build3DWinnerCard() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = 0.05 * (0.5 - _controller.value); // Tilt amount
        
        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // Perspective
            ..rotateX(angle)
            ..rotateY(angle * 0.5),
          alignment: Alignment.center,
          child: _buildWinnerCardContent(),
        );
      },
    );
  }

  Widget _buildWinnerCardContent() {
    final wrongAnswers = widget.totalQuestions - widget.player.correctAnswers;
    
    return Container(
      // margin removed here to be handled by parent or transform
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF7AD), // Gold Light
            Color(0xFFFFA000), // Gold Dark
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66FFC107),
            blurRadius: 30,
            spreadRadius: 5,
            offset: Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
      ),
      child: Column(
        children: [
          // Crown & Rank
          const Icon(Icons.emoji_events_rounded, size: 48, color: Colors.white),
          const SizedBox(height: 16),
          
          // Avatar with Rank Badge
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10),
                  ],
                ),
                child: ProfileAvatar(avatarIndex: widget.player.avatarIndex, size: 90),
              ),
              Positioned(
                bottom: -10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDark,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Text(
                    'المركز الأول',
                    style: TextStyle(
                      color: Colors.white, 
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Name & Score
          Text(
            widget.player.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryDark,
            ),
          ),
          Text(
            '${widget.player.score} نقطة',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: [
                Shadow(color: Colors.black12, offset: Offset(0, 2), blurRadius: 4),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Detailed Stats Row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem('✔️', '${widget.player.correctAnswers}', 'إجابة صحيحة', Colors.green[800]!),
                Container(height: 30, width: 1, color: Colors.white30),
                _buildStatItem('✖️', '$wrongAnswers', 'إجابة خاطئة', Colors.red[800]!),
                Container(height: 30, width: 1, color: Colors.white30),
                _buildStatItem('⏱️', '${(widget.player.totalTimeMs / 1000).toStringAsFixed(1)}s', 'الوقت الكلي', AppTheme.primaryDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankedCard() {
    final wrongAnswers = widget.totalQuestions - widget.player.correctAnswers;
    final isSilver = widget.rank == 2;
    final isBronze = widget.rank == 3;
    final baseColor = isSilver ? const Color(0xFFE0E0E0) : (isBronze ? const Color(0xFFCD7F32) : Colors.white);
    
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isLocalPlayer ? AppTheme.accentColor : Colors.white.withOpacity(0.1),
          width: widget.isLocalPlayer ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Rank Badge
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: baseColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Text(
              '#${widget.rank}',
              style: TextStyle(
                color: baseColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Avatar
          ProfileAvatar(avatarIndex: widget.player.avatarIndex, size: 60),
          
          const SizedBox(height: 12),
          
          // Name & Score
          Text(
            widget.player.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: widget.isLocalPlayer ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${widget.player.score}',
            style: const TextStyle(
              color: AppTheme.accentColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Mini Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMiniStat('✔️', '${widget.player.correctAnswers}'),
              const SizedBox(width: 8),
              _buildMiniStat('✖️', '$wrongAnswers'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String icon, String value, String label, Color color) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
  
  Widget _buildMiniStat(String icon, String value) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 2),
        Text(
          value,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

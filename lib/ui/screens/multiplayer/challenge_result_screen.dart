import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/sound_service.dart';
import '../../../data/services/challenge_game_service.dart';
import '../../widgets/result_card.dart';

/// شاشة نتائج التحدي
class ChallengeResultScreen extends StatefulWidget {
  const ChallengeResultScreen({super.key});

  @override
  State<ChallengeResultScreen> createState() => _ChallengeResultScreenState();
}

class _ChallengeResultScreenState extends State<ChallengeResultScreen>
    with TickerProviderStateMixin {
  late AnimationController _confettiController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _confettiController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    
    _scaleController.forward();
    SoundService().playLevelComplete();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = ChallengeGameService.instance.result;
    final localPlayer = ChallengeGameService.instance.localPlayer;
    
    if (result == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final rankedPlayers = result.rankedPlayers;
    final winner = result.winner;
    final isWinner = localPlayer?.id == result.winnerId;
    final otherPlayers = rankedPlayers.where((p) => p.id != winner.id).toList();
    
    return WillPopScope(
      onWillPop: () async {
        await _exitToHome();
        return false;
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.imperialGradient),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // Header
                  _buildHeader(isWinner),
                  
                  const SizedBox(height: 20),
                  
                  // Winner Card (Always top)
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: ResultCard(
                      player: winner,
                      rank: 1,
                      totalQuestions: result.totalQuestions,
                      isLocalPlayer: localPlayer?.id == winner.id,
                      isWinner: true,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Other Players (Horizontal List)
                  if (otherPlayers.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          const Text(
                            'المنافسون',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${otherPlayers.length} لاعبين',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 240, // Height for compact Rank Cards
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        scrollDirection: Axis.horizontal,
                        itemCount: otherPlayers.length,
                        itemBuilder: (context, index) {
                          final player = otherPlayers[index];
                          // Calculate actual rank based on score position
                          final rank = rankedPlayers.indexOf(player) + 1;
                          
                          return ResultCard(
                            player: player,
                            rank: rank,
                            totalQuestions: result.totalQuestions,
                            isLocalPlayer: localPlayer?.id == player.id,
                            isWinner: false,
                          );
                        },
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 30),
                  
                  // Exit Button
                  _buildExitButton(),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isWinner) {
    return Column(
      children: [
        Text(
          isWinner ? '🎉 انتصار ساحق! 🎉' : '🔥 منافسة قوية!',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Cairo',
            shadows: [Shadow(color: AppTheme.accentColor, blurRadius: 20)],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isWinner ? 'لقد تفوقت على الجميع بجدارة' : 'حظاً أوفر في المرة القادمة',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildExitButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: _exitToHome,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.accentLight, AppTheme.accentColor],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentColor.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.home_rounded, color: AppTheme.primaryDark),
              SizedBox(width: 8),
              Text(
                'العودة للرئيسية',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exitToHome() async {
    SoundService().playClick();
    await ChallengeGameService.instance.reset();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}

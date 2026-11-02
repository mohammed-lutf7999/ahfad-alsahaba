import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/sound_service.dart';
import '../../../data/services/challenge_game_service.dart';
import '../../../data/models/challenge_config.dart';
import '../../widgets/avatar_selector.dart';
import 'multiplayer_quiz_screen.dart';

/// شاشة انتظار اللاعبين (للمضيف)
class WaitingRoomScreen extends StatefulWidget {
  const WaitingRoomScreen({super.key});

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    ChallengeGameService.instance.addListener(_onGameStateChanged);
    debugPrint('🏠 WaitingRoom: initialized, isHost=${ChallengeGameService.instance.isHost}');
  }

  @override
  void dispose() {
    _pulseController.dispose();
    ChallengeGameService.instance.removeListener(_onGameStateChanged);
    super.dispose();
  }

  void _onGameStateChanged() {
    if (mounted) {
      final gameService = ChallengeGameService.instance;
      debugPrint('🔄 WaitingRoom: state changed to ${gameService.state}, players: ${gameService.players.length}');
      
      setState(() {});
      
      // التحقق من بدء اللعبة - يعمل للمضيف والمنضمين
      if (gameService.state == ChallengeState.inProgress) {
        debugPrint('🎮 WaitingRoom: Game is inProgress! Navigating to quiz...');
        _navigateToQuiz();
      }
    }
  }

  void _navigateToQuiz() {
    debugPrint('🚀 WaitingRoom: Navigating to MultiplayerQuizScreen');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MultiplayerQuizScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameService = ChallengeGameService.instance;
    final config = gameService.config;
    final players = gameService.players;
    
    return WillPopScope(
      onWillPop: () async {
        await _showExitDialog();
        return false;
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.imperialGradient),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                
                // Challenge Info
                if (config != null) _buildChallengeInfo(config),
                
                const SizedBox(height: 20),
                
                // Players Grid
                Expanded(
                  child: _buildPlayersGrid(players, config?.maxPlayers ?? 4),
                ),
                
                // Start Button (only for host with 2+ players)
                if (gameService.isHost && players.length >= 2)
                  _buildStartButton(),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Title and Icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppTheme.goldGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: AppTheme.accentColor.withAlpha(80), blurRadius: 10)],
                ),
                child: const Icon(Icons.people_rounded, color: AppTheme.primaryDark, size: 22),
              ),
              const SizedBox(width: 12),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppTheme.accentLight, AppTheme.accentColor],
                ).createShader(bounds),
                child: const Text(
                  'غرفة الانتظار',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          // Exit button
          GestureDetector(
            onTap: () => _showExitDialog(),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withAlpha(80)),
              ),
              child: const Icon(Icons.close_rounded, color: Colors.red, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeInfo(ChallengeConfig config) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem(
            icon: config.type == ChallengeType.bruteForce ? '🎲' : '📚',
            label: config.type == ChallengeType.bruteForce 
                ? 'القوة الغاشمة' 
                : 'قسم محدد',
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildInfoItem(
            icon: '❓',
            label: '${config.questionCount} سؤال',
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildInfoItem(
            icon: '⚡',
            label: config.speedMode ? 'سرعة' : 'عادي',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({required String icon, required String label}) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayersGrid(List players, int maxPlayers) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemCount: maxPlayers,
      itemBuilder: (context, index) {
        if (index < players.length) {
          return _buildPlayerCard(players[index], index == 0);
        } else {
          return _buildEmptySlot(index);
        }
      },
    );
  }

  Widget _buildPlayerCard(dynamic player, bool isHost) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            (isHost ? AppTheme.accentColor : Colors.white).withOpacity(0.15),
            (isHost ? AppTheme.accentColor : Colors.white).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isHost ? AppTheme.accentColor : Colors.white).withOpacity(0.3),
          width: isHost ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Crown for host
          if (isHost)
            const Text('👑', style: TextStyle(fontSize: 24)),
          
          // Avatar
          ProfileAvatar(avatarIndex: player.avatarIndex, size: 60),
          
          const SizedBox(height: 8),
          
          // Name
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
          
          // Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: player.isReady ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
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

  Widget _buildEmptySlot(int index) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03 * _pulseAnimation.value),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_add_rounded,
                size: 40,
                color: Colors.white.withOpacity(0.2),
              ),
              const SizedBox(height: 8),
              Text(
                'في انتظار لاعب...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStartButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {
          SoundService().playClick();
          ChallengeGameService.instance.startGame();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
              SizedBox(width: 8),
              Text(
                'ابدأ التحدي!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showExitDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'مغادرة الغرفة؟',
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'سيتم إلغاء التحدي وإخراج جميع اللاعبين',
          style: TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('البقاء', style: TextStyle(color: AppTheme.accentColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('مغادرة', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await ChallengeGameService.instance.reset();
      Navigator.pop(context);
    }
  }
}

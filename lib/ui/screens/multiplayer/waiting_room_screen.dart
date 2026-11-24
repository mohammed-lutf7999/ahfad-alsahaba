import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/sound_service.dart';
import '../../../data/models/challenge_config.dart';
import '../../../data/services/challenge_game_service.dart';
import 'multiplayer_quiz_screen.dart';
import 'widgets/waiting_room_grid.dart';

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
    debugPrint(
      '🏠 WaitingRoom: initialized, isHost=${ChallengeGameService.instance.isHost}',
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    ChallengeGameService.instance.removeListener(_onGameStateChanged);
    super.dispose();
  }

  void _onGameStateChanged() {
    if (!mounted) return;
    final gameService = ChallengeGameService.instance;
    debugPrint(
      '🔄 WaitingRoom: state changed to ${gameService.state}, players: ${gameService.players.length}',
    );
    setState(() {});

    if (gameService.state == ChallengeState.inProgress) {
      debugPrint('🎮 WaitingRoom: Game is inProgress! Navigating to quiz...');
      _navigateToQuiz();
    }
  }

  void _navigateToQuiz() {
    debugPrint('🚀 WaitingRoom: Navigating to MultiplayerQuizScreen');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MultiplayerQuizScreen()),
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
            child: const Text(
              'البقاء',
              style: TextStyle(color: AppTheme.accentColor),
            ),
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
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameService = ChallengeGameService.instance;
    final config = gameService.config;
    final players = gameService.players;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _showExitDialog();
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.imperialGradient),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                if (config != null) WaitingRoomChallengeInfo(config: config),
                const SizedBox(height: 20),
                Expanded(
                  child: WaitingRoomPlayersGrid(
                    players: players,
                    maxPlayers: config?.maxPlayers ?? 4,
                    pulseAnimation: _pulseAnimation,
                  ),
                ),
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
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentColor.withAlpha(80),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.people_rounded,
                    color: AppTheme.primaryDark,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [AppTheme.accentLight, AppTheme.accentColor],
                      ).createShader(bounds),
                      child: const Text(
                        'غرفة الانتظار',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showExitDialog,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withAlpha(80)),
              ),
              child:
                  const Icon(Icons.close_rounded, color: Colors.red, size: 20),
            ),
          ),
        ],
      ),
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
                color: Colors.green.withValues(alpha: 0.4),
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
}

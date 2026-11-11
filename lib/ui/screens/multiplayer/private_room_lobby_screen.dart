import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/app_theme.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../core/sound_service.dart';
import '../../../core/share_service.dart';
import '../../../data/services/multiplayer_service.dart';
import '../../../data/services/profile_service.dart';
import '../../widgets/animated_avatar_frame.dart';
import '../../widgets/avatar_selector.dart';
import 'online_game_screen.dart';

/// ردهة انتظار الغرفة الخاصة للمضيف
class PrivateRoomLobbyScreen extends StatefulWidget {
  final PrivateRoomResult roomResult;
  final Stream<Map<String, dynamic>>? roomStream;

  const PrivateRoomLobbyScreen({
    super.key,
    required this.roomResult,
    this.roomStream,
  });

  @override
  State<PrivateRoomLobbyScreen> createState() => _PrivateRoomLobbyScreenState();
}

class _PrivateRoomLobbyScreenState extends State<PrivateRoomLobbyScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Timer? _countdownTimer;
  int _secondsLeft = 180; // 3 minutes
  StreamSubscription<Map<String, dynamic>>? _roomSubscription;

  bool _guestJoined = false;
  Map<String, dynamic>? _guestData;
  int _startCountdown = 3;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initCountdown();
    _listenToRoomStatus();
  }

  void _initCountdown() {
    if (widget.roomResult.expiresAt != null) {
      final diff = widget.roomResult.expiresAt!.difference(DateTime.now()).inSeconds;
      _secondsLeft = diff > 0 ? diff : 180;
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsLeft > 1) {
          _secondsLeft--;
        } else {
          timer.cancel();
          _handleTimeout();
        }
      });
    });
  }

  void _listenToRoomStatus() {
    final matchId = widget.roomResult.matchId;
    if (matchId == null) return;

    try {
      final stream = widget.roomStream ??
          MultiplayerService.instance.listenToPrivateRoom(matchId);
      _roomSubscription = stream.listen((data) async {
        if (!mounted || _guestJoined) return;

        final status = data['status'] as String?;
        final guestId = data['player2_id'] as String?;

        if (status == 'matched' && guestId != null) {
          _guestJoined = true;
          _countdownTimer?.cancel();
          unawaited(SoundService().playGameStart());

          // Fetch guest profile info
          final guestInfo =
              await MultiplayerService.instance.fetchOpponentData(guestId);

          if (!mounted) return;
          setState(() {
            _guestData = guestInfo;
          });

          // 3-second launch countdown
          _startLaunchSequence(guestId, data);
        }
      });
    } catch (e) {
      debugPrint('PrivateRoomLobbyScreen: Could not attach room stream: $e');
    }
  }

  void _startLaunchSequence(String guestId, Map<String, dynamic> matchData) {
    _startTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_startCountdown > 1) {
          _startCountdown--;
        } else {
          timer.cancel();
          _launchGame(guestId, matchData);
        }
      });
    });
  }

  void _launchGame(String guestId, Map<String, dynamic> matchData) {
    final seed = widget.roomResult.seed ?? (matchData['seed'] as num?)?.toInt() ?? 1000;
    final questionIds = widget.roomResult.questionIds ??
        (matchData['question_ids'] != null
            ? List<String>.from(matchData['question_ids'])
            : <String>[]);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OnlineGameScreen(
          matchId: widget.roomResult.matchId!,
          opponentId: guestId,
          seed: seed,
          questionIds: questionIds,
          opponentName: _guestData?['display_name'] ?? 'الفارس الضيف',
          opponentAvatarIndex: _guestData?['avatar_index'] ?? 0,
          isBot: false,
        ),
      ),
    );
  }

  void _handleTimeout() {
    if (_guestJoined) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'انتهت مهلة الغرفة (3 دقائق) دون انضمام الصديق',
          style: TextStyle(fontFamily: 'Cairo'),
          textAlign: TextAlign.center,
        ),
        backgroundColor: Colors.redAccent,
      ),
    );
    _cancelAndLeave();
  }

  void _cancelAndLeave() {
    final matchId = widget.roomResult.matchId;
    if (matchId != null) {
      unawaited(MultiplayerService.instance.cancelPrivateRoom(matchId));
    }
    Navigator.of(context).pop();
  }

  void _copyCode() {
    final code = widget.roomResult.roomCode ?? '';
    Clipboard.setData(ClipboardData(text: code));
    SoundService().playClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ الكود ($code) بنجاح 📋',
          style: const TextStyle(fontFamily: 'Cairo'),
          textAlign: TextAlign.center,
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.accentColor,
      ),
    );
  }

  void _shareViaWhatsApp() {
    final code = widget.roomResult.roomCode ?? '';
    SoundService().playClick();
    final message = 'أتحداك في مسابقة «معركة أحفاد الصحابة»! ⚔️\n'
        'كود الغرفة الخاص بي هو: $code\n'
        'افتح التطبيق، اختر (وضع التحدي ➔ الغرف الخاصة) وأدخل الكود لتبدأ المعركة معي الآن! 🏆';

    ShareService.shareText(message);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _startTimer?.cancel();
    _roomSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatTimer(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final myProfile = ProfileService.instance.activeProfile;
    final code = widget.roomResult.roomCode ?? '------';
    final formattedCode = code.length == 6
        ? '${code.substring(0, 3)} - ${code.substring(3)}'
        : code;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _cancelAndLeave();
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: AppCustomTheme.of(context).backgroundGradient,
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _cancelAndLeave,
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white70),
                        tooltip: 'إلغاء الغرفة',
                      ),
                      const Text(
                        'غرفة التحدي الخاص ⚔️',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(width: 48), // Balance spacing
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),

                        // PIN Code Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 20),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryDark.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.accentColor.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accentColor.withValues(alpha: 0.1),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'رمز دخول الغرفة الذهبي',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                              const SizedBox(height: 8),
                              FittedBox(
                                child: Text(
                                  formattedCode,
                                  style: const TextStyle(
                                    color: AppTheme.accentColor,
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 4,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Copy & Share buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(
                                            color: Colors.white30),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      onPressed: _copyCode,
                                      icon: const Icon(Icons.copy_rounded,
                                          size: 16),
                                      label: const Text(
                                        'نسخ الكود',
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 13,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF25D366),
                                        foregroundColor: Colors.white,
                                        elevation: 3,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      onPressed: _shareViaWhatsApp,
                                      icon: const Icon(Icons.send_rounded,
                                          size: 16),
                                      label: const Text(
                                        'مشاركة واتساب',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Cairo',
                                          fontSize: 13,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Opponents Matchup Visualizer
                        Row(
                          children: [
                            // Host Card (Me)
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.greenAccent.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    AnimatedAvatarFrame(
                                      size: 56,
                                      frameKey: myProfile?.equippedFrame ??
                                          'frame_bronze',
                                      child: ProfileAvatar(
                                        avatarIndex: myProfile?.avatarIndex ?? 0,
                                        size: 46,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      myProfile?.name ?? 'المضيف',
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
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        '👑 المضيف (جاهز)',
                                        style: TextStyle(
                                          color: Colors.greenAccent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Cairo',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // VS Badge
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: _guestJoined
                                  ? Container(
                                      width: 44,
                                      height: 44,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppTheme.accentColor,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$_startCountdown',
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
                                        color: AppTheme.accentColor
                                            .withValues(alpha: 0.8),
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                            ),

                            // Guest Slot (Friend)
                            Expanded(
                              child: _guestJoined
                                  ? Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: AppTheme.accentColor
                                              .withValues(alpha: 0.6),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          AnimatedAvatarFrame(
                                            size: 56,
                                            frameKey:
                                                _guestData?['equipped_frame'] ??
                                                    'frame_bronze',
                                            child: ProfileAvatar(
                                              avatarIndex: (_guestData?['avatar_index'] as num?)?.toInt() ?? 0,
                                              size: 46,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _guestData?['display_name'] ??
                                                _guestData?['name'] ??
                                                'الفارس الضيف',
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
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.green
                                                  .withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              '⚔️ انضم للنزال!',
                                              style: TextStyle(
                                                color: Colors.greenAccent,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'Cairo',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ScaleTransition(
                                      scale: _pulseAnimation,
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.03),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: AppTheme.accentColor
                                                .withValues(alpha: 0.3),
                                            style: BorderStyle.solid,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Container(
                                              width: 56,
                                              height: 56,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white
                                                    .withValues(alpha: 0.05),
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
                                    ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // Expiry Timer Indicator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.timer_outlined,
                                color: Colors.amberAccent, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'مهلة صلاحية الغرفة: ${_formatTimer(_secondsLeft)}',
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        // Cancel Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _cancelAndLeave,
                            child: const Text(
                              'إلغاء الغرفة والعودة',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

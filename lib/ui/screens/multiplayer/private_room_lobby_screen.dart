import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_theme.dart';
import '../../../core/share_service.dart';
import '../../../core/sound_service.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../data/services/multiplayer_service.dart';
import '../../../data/services/profile_service.dart';
import 'online_game_screen.dart';
import 'widgets/pin_code_boxes_widget.dart';
import 'widgets/private_room_matchup_row.dart';

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
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  Timer? _countdownTimer;
  int _secondsLeft = 180;
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
      final diff =
          widget.roomResult.expiresAt!.difference(DateTime.now()).inSeconds;
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

          final guestInfo =
              await MultiplayerService.instance.fetchOpponentData(guestId);
          if (!mounted) return;
          setState(() => _guestData = guestInfo);
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
    final seed =
        widget.roomResult.seed ?? (matchData['seed'] as num?)?.toInt() ?? 1000;
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
    ShareService.shareText(
      'أتحداك في مسابقة «معركة أحفاد الصحابة»! ⚔️\n'
      'كود الغرفة الخاص بي هو: $code\n'
      'افتح التطبيق، اختر (وضع التحدي ➔ الغرف الخاصة) وأدخل الكود لتبدأ المعركة معي الآن! 🏆',
    );
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
    final formattedCode =
        code.length == 6 ? '${code.substring(0, 3)} - ${code.substring(3)}' : code;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancelAndLeave();
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: AppCustomTheme.of(context).backgroundGradient,
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _cancelAndLeave,
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white70,
                        ),
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
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        PinCodeDisplayCard(
                          formattedCode: formattedCode,
                          onCopyCode: _copyCode,
                          onShareWhatsApp: _shareViaWhatsApp,
                        ),
                        const SizedBox(height: 24),
                        PrivateRoomMatchupRow(
                          hostName: myProfile?.name ?? 'المضيف',
                          hostAvatarIndex: myProfile?.avatarIndex ?? 0,
                          hostFrameKey:
                              myProfile?.equippedFrame ?? 'frame_bronze',
                          guestJoined: _guestJoined,
                          guestData: _guestData,
                          startCountdown: _startCountdown,
                          pulseAnimation: _pulseAnimation,
                        ),
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              color: Colors.amberAccent,
                              size: 18,
                            ),
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
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
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

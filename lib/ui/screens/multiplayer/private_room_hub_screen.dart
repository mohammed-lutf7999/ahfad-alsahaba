import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/sound_service.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/app_control_models.dart';
import '../../../data/services/app_control_service.dart';
import '../../../data/services/multiplayer_service.dart';
import 'online_game_screen.dart';
import 'private_room_lobby_screen.dart';
import 'widgets/pin_code_boxes_widget.dart';
import 'widgets/private_room_hub_cards.dart';

/// شاشة بوابة غرف التحدي الخاصة وتحدي الأصدقاء
class PrivateRoomHubScreen extends StatefulWidget {
  const PrivateRoomHubScreen({super.key});

  @override
  State<PrivateRoomHubScreen> createState() => _PrivateRoomHubScreenState();
}

class _PrivateRoomHubScreenState extends State<PrivateRoomHubScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();

  bool _isCreatingRoom = false;
  bool _isJoiningRoom = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleCreateRoom() async {
    SoundService().playClick();
    setState(() {
      _isCreatingRoom = true;
      _errorMessage = '';
    });

    final result = await MultiplayerService.instance.createPrivateRoom();
    if (!mounted) return;
    setState(() => _isCreatingRoom = false);

    if (result.success && result.matchId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PrivateRoomLobbyScreen(roomResult: result),
        ),
      );
    } else {
      _showError(
        result.error ?? 'تعذر إنشاء الغرفة السحابية، يرجى المحاولة ثانية',
      );
    }
  }

  Future<void> _handleJoinRoom() async {
    final code = _pinController.text.trim();
    if (code.length != 6) {
      _showError('يرجى إدخال رمز الغرفة كاملاً (6 أرقام)');
      return;
    }

    SoundService().playClick();
    setState(() {
      _isJoiningRoom = true;
      _errorMessage = '';
    });

    final result = await MultiplayerService.instance.joinPrivateRoom(code);
    if (!mounted) return;
    setState(() => _isJoiningRoom = false);

    if (result.success && result.matchId != null) {
      SoundService().playGameStart();
      final hostId = result.opponentId ?? '';
      final hostData =
          await MultiplayerService.instance.fetchOpponentData(hostId);
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OnlineGameScreen(
            matchId: result.matchId!,
            opponentId: hostId,
            seed: result.seed ?? 1000,
            questionIds: result.questionIds ?? [],
            opponentName: hostData?['display_name'] ?? 'الفارس المضيف',
            opponentAvatarIndex: hostData?['avatar_index'] ?? 0,
          ),
        ),
      );
    } else {
      _showError(
        result.error ??
            'تعذر الانضمام للغرفة. تأكد من صحة الرمز وعدم انتهاء مهلته',
      );
    }
  }

  Future<void> _handlePasteCode() async {
    final clipData = await Clipboard.getData('text/plain');
    final digits = (clipData?.text?.trim() ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 6) {
      setState(() {
        _pinController.text = digits.substring(0, 6);
        _errorMessage = '';
      });
      SoundService().playClick();
    } else if (digits.isNotEmpty) {
      setState(() => _pinController.text = digits);
    }
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Cairo'),
          textAlign: TextAlign.center,
        ),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppCustomTheme.of(context).backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white70,
                      ),
                    ),
                    const Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'غرف التحدي الخاصة ⚔️',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: ValueListenableBuilder<AppFeatureFlags>(
                  valueListenable:
                      AppControlService.instance.featureFlagsNotifier,
                  builder: (context, flags, _) {
                    if (!flags.privateRooms) {
                      return PrivateRoomDisabledCard(
                        onBack: () => Navigator.of(context).pop(),
                      );
                    }
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          PrivateRoomCreateCard(
                            isCreating: _isCreatingRoom,
                            onCreate: _handleCreateRoom,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Expanded(
                                child: Divider(color: Colors.white24),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'أو',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo',
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: Divider(color: Colors.white24),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          PrivateRoomJoinCard(
                            pinController: _pinController,
                            pinFocusNode: _pinFocusNode,
                            isJoining: _isJoiningRoom,
                            onPinChanged: (_) => setState(() {}),
                            onPasteCode: _handlePasteCode,
                            onJoin: _handleJoinRoom,
                          ),
                          if (_errorMessage.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.redAccent.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                _errorMessage,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                  fontFamily: 'Cairo',
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

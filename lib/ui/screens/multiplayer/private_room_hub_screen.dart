import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/app_theme.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../core/sound_service.dart';
import '../../../data/services/multiplayer_service.dart';
import 'private_room_lobby_screen.dart';
import 'online_game_screen.dart';

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
      _showError(result.error ?? 'تعذر إنشاء الغرفة السحابية، يرجى المحاولة ثانية');
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

      // Fetch host info
      final hostData = await MultiplayerService.instance.fetchOpponentData(hostId);

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
            isBot: false,
          ),
        ),
      );
    } else {
      _showError(result.error ?? 'تعذر الانضمام للغرفة. تأكد من صحة الرمز وعدم انتهاء مهلته');
    }
  }

  Future<void> _handlePasteCode() async {
    final clipData = await Clipboard.getData('text/plain');
    final text = clipData?.text?.trim() ?? '';
    // Extract only digits
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 6) {
      final code = digits.substring(0, 6);
      setState(() {
        _pinController.text = code;
        _errorMessage = '';
      });
      SoundService().playClick();
    } else if (digits.isNotEmpty) {
      setState(() {
        _pinController.text = digits;
      });
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
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white70),
                    ),
                    const Text(
                      'غرف التحدي الخاصة ⚔️',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(width: 48), // Balance
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),

                      // Card 1: Create Room
                      _buildCreateRoomCard(),

                      const SizedBox(height: 20),

                      // Divider "أو"
                      Row(
                        children: [
                          const Expanded(child: Divider(color: Colors.white24)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
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
                          const Expanded(child: Divider(color: Colors.white24)),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Card 2: Join Room
                      _buildJoinRoomCard(),

                      if (_errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.redAccent.withValues(alpha: 0.5)),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateRoomCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.accentColor.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_home_work_rounded,
                    color: AppTheme.accentColor, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إنشاء غرفة جديدة',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    Text(
                      'أنشئ كوداً وادعُ صديقك عبر واتساب',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: AppTheme.primaryDark,
                elevation: 3,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isCreatingRoom ? null : _handleCreateRoom,
              icon: _isCreatingRoom
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryDark,
                      ),
                    )
                  : const Icon(Icons.castle_rounded, size: 20),
              label: Text(
                _isCreatingRoom ? 'جاري إنشاء الغرفة...' : 'إنشاء غرفة خاصة 🏰',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  fontFamily: 'Cairo',
                  height: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinRoomCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white12,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.vpn_key_rounded,
                    color: Colors.blueAccent, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الانضمام إلى غرفة صديق',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    Text(
                      'أدخل الرمز السداسي الذي أرسله لك صديقك',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 6-Digit PIN Boxes display
          GestureDetector(
            onTap: () => _pinFocusNode.requestFocus(),
            child: Stack(
              children: [
                // Hidden Real TextField
                Opacity(
                  opacity: 0.0,
                  child: TextField(
                    controller: _pinController,
                    focusNode: _pinFocusNode,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (val) => setState(() {}),
                  ),
                ),

                // Styled Visual PIN Boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) {
                    final text = _pinController.text;
                    final digit = index < text.length ? text[index] : '';
                    final isFocused = index == text.length;

                    return Container(
                      width: 42,
                      height: 50,
                      margin: EdgeInsets.only(
                        left: index == 3 ? 12 : 4,
                        right: index == 2 ? 12 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isFocused
                              ? AppTheme.accentColor
                              : (digit.isNotEmpty
                                  ? AppTheme.accentColor.withValues(alpha: 0.6)
                                  : Colors.white24),
                          width: isFocused ? 2.0 : 1.0,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          digit,
                          style: const TextStyle(
                            color: AppTheme.accentColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Paste code button
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _handlePasteCode,
              icon: const Icon(Icons.paste_rounded,
                  size: 16, color: AppTheme.accentColor),
              label: const Text(
                'لصق الكود من الحافظة',
                style: TextStyle(
                  color: AppTheme.accentColor,
                  fontSize: 12,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Join Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981), // Emerald
                foregroundColor: Colors.white,
                elevation: 3,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isJoiningRoom ? null : _handleJoinRoom,
              icon: _isJoiningRoom
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sports_kabaddi_rounded, size: 20),
              label: Text(
                _isJoiningRoom ? 'جاري الانضمام...' : 'دخول المعركة الآن ⚔️',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  fontFamily: 'Cairo',
                  height: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

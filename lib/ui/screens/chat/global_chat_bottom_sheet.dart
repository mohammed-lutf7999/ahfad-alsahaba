import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/sound_service.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/chat_message_model.dart';
import '../../../data/services/app_control_service.dart';
import '../../../data/services/chat_service.dart';
import '../../../data/services/multiplayer_service.dart';
import '../../widgets/top_notification.dart';
import '../multiplayer/online_game_screen.dart';
import '../multiplayer/private_room_lobby_screen.dart';
import 'widgets/chat_bubble_widget.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/chat_sheet_chrome.dart';

/// Modal bottom sheet for «ديوان الأحفاد 💬» live global chat.
/// Opens the Realtime WebSocket channel strictly while visible and closes it
/// unconditionally inside `dispose()`.
class GlobalChatBottomSheet extends StatefulWidget {
  final String channel;

  const GlobalChatBottomSheet({super.key, this.channel = 'global'});

  static Future<void> show(BuildContext context, {String channel = 'global'}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GlobalChatBottomSheet(channel: channel),
    );
  }

  @override
  State<GlobalChatBottomSheet> createState() => _GlobalChatBottomSheetState();
}

class _GlobalChatBottomSheetState extends State<GlobalChatBottomSheet> {
  final ChatService _chat = ChatService.instance;
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  String? _inlineFeedback;
  bool _isJoiningInvite = false;

  @override
  void initState() {
    super.initState();
    _chat.addListener(_onChatUpdated);
    AppControlService.instance.featureFlagsNotifier
        .addListener(_onControlUpdated);
    AppControlService.instance.playerPermissionsNotifier
        .addListener(_onControlUpdated);
    AppControlService.instance.isAdminNotifier.addListener(_onControlUpdated);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _chat.openChannel(widget.channel);
      }
    });
  }

  void _onControlUpdated() {
    if (mounted) setState(() {});
  }

  void _onChatUpdated() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _chat.removeListener(_onChatUpdated);
    AppControlService.instance.featureFlagsNotifier
        .removeListener(_onControlUpdated);
    AppControlService.instance.playerPermissionsNotifier
        .removeListener(_onControlUpdated);
    AppControlService.instance.isAdminNotifier
        .removeListener(_onControlUpdated);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    // Crucial Free-Plan guard: release chat Realtime socket immediately on close.
    unawaited(_chat.closeChannel());
    super.dispose();
  }

  Future<void> _handleReportMessage(ChatMessageModel msg) async {
    if (!_chat.isCurrentUserAuthenticated) {
      TopNotification.showWarning(context, 'سجّل الدخول للإبلاغ عن مخالفة');
      return;
    }
    final selected = await showChatReportReasonDialog(context);
    if (selected == null || !mounted) return;
    final ok = await _chat.reportMessage(msg.id, reason: selected);
    if (!mounted) return;
    TopNotification.showSuccess(
      context,
      ok
          ? 'تم استلام البلاغ للمراجعة ($selected) 🛡️'
          : 'تعذر إرسال البلاغ حالياً',
    );
  }

  Future<void> _send() async {
    final text = _msgCtrl.text;
    setState(() => _inlineFeedback = null);
    final err = await _chat.sendMessage(text, channel: widget.channel);
    if (!mounted) return;
    if (err != null) {
      setState(() => _inlineFeedback = err);
    } else {
      SoundService().playClick();
      _msgCtrl.clear();
    }
  }

  Future<void> _createAndShareChallenge() async {
    SoundService().playClick();
    setState(() => _inlineFeedback = null);
    final res = await _chat.sendChallengeInvite(channel: widget.channel);
    if (!mounted) return;
    if (!res.success || res.matchId == null) {
      setState(
        () => _inlineFeedback = res.error ?? 'تعذر إطلاق التحدي من الديوان',
      );
      return;
    }
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrivateRoomLobbyScreen(roomResult: res),
      ),
    );
  }

  Future<void> _joinChallengeInvite(ChatMessageModel msg) async {
    final code = msg.inviteRoomCode;
    if (code == null || _isJoiningInvite) return;
    SoundService().playClick();
    setState(() {
      _isJoiningInvite = true;
      _inlineFeedback = null;
    });
    try {
      final result = await MultiplayerService.instance.joinPrivateRoom(code);
      if (!mounted) return;
      if (result.success && result.matchId != null) {
        final hostId = result.opponentId ?? '';
        final hostData =
            await MultiplayerService.instance.fetchOpponentData(hostId);
        if (!mounted) return;
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OnlineGameScreen(
              matchId: result.matchId!,
              opponentId: hostId,
              seed: result.seed ?? 1000,
              questionIds: result.questionIds ?? [],
              opponentName:
                  (hostData?['display_name'] ?? msg.displayName).toString(),
              opponentAvatarIndex:
                  (hostData?['avatar_index'] as num?)?.toInt() ??
                      msg.avatarIndex,
              isBot: false,
            ),
          ),
        );
      } else {
        setState(
          () => _inlineFeedback =
              result.error ?? 'انتهت مهلة الغرفة أو اكتمل عددها',
        );
      }
    } finally {
      if (mounted) setState(() => _isJoiningInvite = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final accent = customTheme.sovereignAccent;
    final control = AppControlService.instance;
    final isAdmin = control.isAdminNotifier.value;
    final diwanEnabled = isAdmin || control.featureFlagsNotifier.value.diwanChat;
    final perms = control.playerPermissionsNotifier.value;
    final canWriteInDiwan = isAdmin ||
        (!perms.isEffectivelyBannedNow &&
            perms.canUseDiwan &&
            !perms.isEffectivelyDiwanMutedNow);
    final myUid = _chat.currentUserId;
    final media = MediaQuery.of(context);
    final sheetHeight = (media.size.height * 0.82).clamp(380.0, 680.0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Container(
          height: sheetHeight,
          decoration: BoxDecoration(
            gradient: customTheme.backgroundGradient,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border.all(
              color: accent.withValues(alpha: 0.45),
              width: 1.4,
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                ChatSheetHeader(
                  showChallengeButton: diwanEnabled &&
                      _chat.isCurrentUserAuthenticated &&
                      canWriteInDiwan,
                  isSending: _chat.isSending,
                  onChallenge: _createAndShareChallenge,
                  onClose: () => Navigator.of(context).pop(),
                ),
                if (!diwanEnabled)
                  const Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'ديوان الأحفاد متوقف مؤقتاً للصيانة من الإدارة.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white70,
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                else ...[
                  Expanded(
                    child: _chat.isLoading && _chat.messages.isEmpty
                        ? Center(
                            child: CircularProgressIndicator(color: accent),
                          )
                        : _chat.messages.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'ابدأ التحية في ديوان الأحفاد!\n«السلام عليكم ورحمة الله»',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      color:
                                          Colors.white.withValues(alpha: 0.72),
                                      fontSize: 14,
                                      height: 1.6,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollCtrl,
                                padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
                                itemCount: _chat.messages.length,
                                itemBuilder: (context, index) {
                                  final msg = _chat.messages[index];
                                  final isMine =
                                      myUid != null && msg.userId == myUid;
                                  return ChatBubbleWidget(
                                    message: msg,
                                    isMine: isMine,
                                    isAdmin: isAdmin,
                                    onJoinChallenge: msg.isChallengeInvite
                                        ? () => _joinChallengeInvite(msg)
                                        : null,
                                    onReport: () => _handleReportMessage(msg),
                                    onAdminDelete: () => _chat.adminModerate(
                                      action: 'delete_message',
                                      messageId: msg.id,
                                      reason: 'حذف من المشرف',
                                    ),
                                    onAdminMute: () => _chat.adminModerate(
                                      action: 'mute_user',
                                      targetUserId: msg.userId,
                                      reason: 'كتم إداري 24 ساعة',
                                    ),
                                  );
                                },
                              ),
                  ),
                  if (_inlineFeedback != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          _inlineFeedback!,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.amberAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ChatInputBar(
                    controller: _msgCtrl,
                    isAuthenticated: _chat.isCurrentUserAuthenticated,
                    isSending: _chat.isSending,
                    onSend: _send,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

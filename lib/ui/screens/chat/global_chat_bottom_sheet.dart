import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
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

/// Modal bottom sheet for «ديوان الأحفاد 💬» live global chat.
/// Opens the Realtime WebSocket channel strictly while visible and closes it
/// unconditionally inside `dispose()`.
class GlobalChatBottomSheet extends StatefulWidget {
  final String channel;

  const GlobalChatBottomSheet({
    super.key,
    this.channel = 'global',
  });

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
    AppControlService.instance.featureFlagsNotifier.addListener(_onControlUpdated);
    AppControlService.instance.playerPermissionsNotifier.addListener(_onControlUpdated);
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
    AppControlService.instance.featureFlagsNotifier.removeListener(_onControlUpdated);
    AppControlService.instance.playerPermissionsNotifier.removeListener(_onControlUpdated);
    AppControlService.instance.isAdminNotifier.removeListener(_onControlUpdated);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    // Crucial Free-Plan guard: release chat Realtime socket immediately on close.
    unawaited(_chat.closeChannel());
    super.dispose();
  }

  Future<void> _showReportReasonDialog(ChatMessageModel msg) async {
    if (!_chat.isCurrentUserAuthenticated) {
      TopNotification.showWarning(context, 'سجّل الدخول للإبلاغ عن مخالفة');
      return;
    }
    const reasons = <String>[
      'ألفاظ غير لائقة',
      'رابط أو إعلان مخالف',
      'إزعاج وتكرار/سبام',
    ];
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppTheme.primaryDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'سبب الإبلاغ عن الرسالة 🛡️',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final reason in reasons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(reason),
                    child: Text(
                      reason,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'إلغاء',
                style: TextStyle(fontFamily: 'Cairo', color: Colors.white60),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final ok = await _chat.reportMessage(msg.id, reason: selected);
    if (!mounted) return;
    TopNotification.showSuccess(
      context,
      ok ? 'تم استلام البلاغ للمراجعة ($selected) 🛡️' : 'تعذر إرسال البلاغ حالياً',
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  child: Row(
                    children: [
                      Icon(Icons.forum_rounded, color: accent, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ديوان الأحفاد 💬',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: accent,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'تواصل راقٍ وتحديات سريعة (تُحفظ 24 ساعة)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.white.withValues(alpha: 0.68),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (diwanEnabled &&
                          _chat.isCurrentUserAuthenticated &&
                          canWriteInDiwan)
                        SizedBox(
                          height: 36,
                          child: ElevatedButton.icon(
                            key: const Key('diwan_challenge_btn'),
                            onPressed:
                                _chat.isSending ? null : _createAndShareChallenge,
                            icon: const Icon(
                              Icons.sports_kabaddi_rounded,
                              size: 15,
                            ),
                            label: const Text(
                              'تحدّاني',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: AppTheme.primaryDark,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      ),
                    ],
                  ),
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
                                  color: Colors.white.withValues(alpha: 0.72),
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
                              final isMine = myUid != null && msg.userId == myUid;
                              return ChatBubbleWidget(
                                message: msg,
                                isMine: isMine,
                                isAdmin: isAdmin,
                                onJoinChallenge: msg.isChallengeInvite
                                    ? () => _joinChallengeInvite(msg)
                                    : null,
                                onReport: () => _showReportReasonDialog(msg),
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
                  _buildInputBar(customTheme, accent),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(AppCustomTheme customTheme, Color accent) {
    if (!_chat.isCurrentUserAuthenticated) {
      return Container(
        margin: const EdgeInsets.fromLTRB(14, 4, 14, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: customTheme.surfaceCard.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: accent, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'سجّل دخولك بحساب Google من القائمة للمشاركة في الديوان وتحدي الفرسان',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final control = AppControlService.instance;
    final isAdmin = control.isAdminNotifier.value;
    final perms = control.playerPermissionsNotifier.value;
    if (!isAdmin && (!perms.canUseDiwan || perms.isEffectivelyDiwanMutedNow)) {
      final isMuted = perms.isEffectivelyDiwanMutedNow;
      final until = perms.diwanMutedUntil?.toLocal();
      final untilLabel = until != null
          ? '${until.year}-${until.month.toString().padLeft(2, '0')}-${until.day.toString().padLeft(2, '0')} '
            '${until.hour.toString().padLeft(2, '0')}:${until.minute.toString().padLeft(2, '0')}'
          : null;
      final reasonText = perms.diwanMuteReason.trim();
      final statusMessage = !perms.canUseDiwan
          ? 'تم تقييد المشاركة في ديوان الأحفاد على هذا الحساب من الإدارة.'
          : 'تم كتم مشاركتك في الديوان مؤقتاً'
            '${reasonText.isNotEmpty ? ' ($reasonText)' : ''}'
            '${untilLabel != null ? ' — ينتهي: $untilLabel' : ''}.';
      return Container(
        key: const Key('diwan_muted_status_bar'),
        margin: const EdgeInsets.fromLTRB(14, 4, 14, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Icon(
              isMuted ? Icons.volume_off_rounded : Icons.block_rounded,
              color: Colors.amberAccent,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                statusMessage,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('diwan_message_input'),
              controller: _msgCtrl,
              maxLength: 250,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontSize: 13.5,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'اكتب تحية أو رسالة مهذبة...',
                hintStyle: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: customTheme.surfaceCard.withValues(alpha: 0.85),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: accent.withValues(alpha: 0.35)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: accent.withValues(alpha: 0.35)),
                ),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 46,
            width: 48,
            child: ElevatedButton(
              key: const Key('diwan_send_btn'),
              onPressed: _chat.isSending ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: AppTheme.primaryDark,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _chat.isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

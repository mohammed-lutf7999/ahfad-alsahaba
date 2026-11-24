import 'package:flutter/material.dart';

import '../../../core/app_constants.dart';
import '../../../core/app_routes.dart';
import '../../../core/app_theme.dart';
import '../../../core/sound_service.dart';
import '../../../data/models/app_control_models.dart';
import '../../../data/services/app_control_service.dart';
import '../../../data/services/auth_service.dart';
import '../chat/global_chat_bottom_sheet.dart';
import '../guilds/guild_dashboard_screen.dart';
import 'create_challenge_screen.dart';
import 'join_challenge_screen.dart';
import 'lobby_screen.dart';
import 'private_room_hub_screen.dart';
import 'widgets/challenge_mode_card.dart';
import 'widgets/nearby_role_bottom_sheet.dart';

/// القائمة الرئيسية لوضع التحدي (منظومة الأونلاين والبلوتوث المحلي)
class ChallengeMenuScreen extends StatefulWidget {
  const ChallengeMenuScreen({super.key});

  @override
  State<ChallengeMenuScreen> createState() => _ChallengeMenuScreenState();
}

class _ChallengeMenuScreenState extends State<ChallengeMenuScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _handleGatedTap({
    required bool isEnabled,
    required String disabledMessage,
    required VoidCallback onProceed,
  }) {
    if (!isEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(disabledMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    onProceed();
  }

  void _launchDailyChallenge() {
    const categories = [
      AppConstants.quranCategory,
      AppConstants.hadithCategory,
      AppConstants.fiqhCategory,
      AppConstants.seerahCategory,
      AppConstants.historyCategory,
      AppConstants.aqeedahCategory,
    ];
    final now = DateTime.now();
    final daySeed = now.year * 1000 + now.month * 31 + now.day;
    final categoryId = categories[daySeed % categories.length];
    final levelNumber = (daySeed % 10) + 1;

    Navigator.pushNamed(
      context,
      AppRoutes.quiz,
      arguments: {
        'categoryId': categoryId,
        'levelId': '${categoryId}_level_$levelNumber',
        'levelNumber': levelNumber,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.imperialGradient),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: ValueListenableBuilder<AppFeatureFlags>(
                      valueListenable:
                          AppControlService.instance.featureFlagsNotifier,
                      builder: (context, flags, _) =>
                          ValueListenableBuilder<PlayerPermissions>(
                        valueListenable:
                            AppControlService.instance.playerPermissionsNotifier,
                        builder: (context, perms, _) =>
                            _buildMenuBody(flags, perms),
                      ),
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

  Widget _buildMenuBody(AppFeatureFlags flags, PlayerPermissions perms) {
    final isAdmin = AppControlService.instance.isAdminNotifier.value;
    final isLoggedIn = AuthService().isLoggedIn;
    final banned = !isAdmin && perms.isEffectivelyBannedNow;
    final onlineOk = !banned && (isAdmin || perms.canUseOnline);

    final privateAllowed = (isAdmin || flags.privateRooms) && onlineOk;
    final quickOnlineAllowed = (isAdmin || flags.onlineMultiplayer) && onlineOk;
    final diwanAllowed = (isAdmin || flags.diwanChat) &&
        !banned &&
        (isAdmin || !isLoggedIn || perms.canUseDiwan);
    final guildsAllowed = (isAdmin || flags.guildsArenas) &&
        !banned &&
        (isAdmin || !isLoggedIn || perms.canUseGuilds);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const ChallengeVsEmblem(),
        const SizedBox(height: 24),
        ChallengeModeCard(
          icon: Icons.castle_rounded,
          title: 'غرف التحدي الخاصة 🏰',
          subtitle: privateAllowed
              ? 'كود سداسي ودعوة الأصدقاء عبر واتساب'
              : (!flags.privateRooms
                  ? 'متوفرة قريباً — متوقفة مؤقتاً للصيانة 🔒'
                  : 'تم تقييد اللعب الأونلاين على هذا الحساب 🔒'),
          color: AppTheme.accentColor,
          isEnabled: privateAllowed,
          onTap: () => _handleGatedTap(
            isEnabled: privateAllowed,
            disabledMessage: !flags.privateRooms
                ? 'غرف التحدي الخاصة متوقفة مؤقتاً للصيانة والتحديث 🛡️'
                : 'تم تقييد اللعب الأونلاين على هذا الحساب من الإدارة 🔒',
            onProceed: () => _navigateTo(const PrivateRoomHubScreen()),
          ),
        ),
        const SizedBox(height: 16),
        ChallengeModeCard(
          icon: Icons.radar_rounded,
          title: 'الميدان السريع المباشر ⚔️',
          subtitle: quickOnlineAllowed
              ? 'مطابقة أونلاين فورية أو ضد البوت'
              : (!flags.onlineMultiplayer
                  ? 'المباريات الأونلاين متوقفة مؤقتاً للصيانة 🔒'
                  : 'تم تقييد اللعب الأونلاين على هذا الحساب 🔒'),
          color: AppTheme.accentLight,
          isEnabled: quickOnlineAllowed,
          onTap: () => _handleGatedTap(
            isEnabled: quickOnlineAllowed,
            disabledMessage: !flags.onlineMultiplayer
                ? 'الميدان السريع الأونلاين متوقف مؤقتاً للصيانة والتحديث 🛡️'
                : 'تم تقييد اللعب الأونلاين على هذا الحساب من الإدارة 🔒',
            onProceed: () => _navigateTo(const LobbyScreen()),
          ),
        ),
        const SizedBox(height: 16),
        ChallengeModeCard(
          icon: Icons.bluetooth_searching_rounded,
          title: 'تحدي البلوتوث المحلي 📡',
          subtitle: 'تنافس بدون إنترنت مع الأجهزة القريبة',
          color: Colors.blueAccent,
          onTap: () => showNearbyRoleBottomSheet(
            context,
            onHostSelected: () => _navigateTo(const CreateChallengeScreen()),
            onGuestSelected: () => _navigateTo(const JoinChallengeScreen()),
          ),
        ),
        if (flags.dailyChallenges) ...[
          const SizedBox(height: 16),
          ChallengeModeCard(
            icon: Icons.auto_awesome_rounded,
            title: 'التحدي اليومي المتجدد 🌟',
            subtitle: 'جولة يومية متجددة عبر السحابة والمواسم',
            color: const Color(0xFF10B981),
            onTap: _launchDailyChallenge,
          ),
        ],
        const SizedBox(height: 16),
        ChallengeModeCard(
          icon: Icons.forum_rounded,
          title: 'ديوان الأحفاد 💬',
          subtitle: diwanAllowed
              ? 'التعارف المهذب وإطلاق تحديات الغرف الخاصة'
              : (!flags.diwanChat
                  ? 'الديوان متوقف مؤقتاً للصيانة 🔒'
                  : 'تم تقييد المشاركة في الديوان من الإدارة 🔒'),
          color: const Color(0xFF38BDF8),
          isEnabled: diwanAllowed,
          onTap: () => _handleGatedTap(
            isEnabled: diwanAllowed,
            disabledMessage: !flags.diwanChat
                ? 'ديوان الأحفاد متوقف مؤقتاً للصيانة والتحديث 🛡️'
                : 'تم تقييد المشاركة في ديوان الأحفاد من الإدارة 🔒',
            onProceed: () => GlobalChatBottomSheet.show(context),
          ),
        ),
        const SizedBox(height: 16),
        ChallengeModeCard(
          icon: Icons.shield_rounded,
          title: 'الكتائب والبطولات الحية 🛡️',
          subtitle: guildsAllowed
              ? 'رايات الكتائب، معركة الجمعة، وغرف 100 مشارك'
              : (!flags.guildsArenas
                  ? 'الكتائب متوقفة مؤقتاً للصيانة 🔒'
                  : 'تم تقييد نظام الكتائب من الإدارة 🔒'),
          color: Colors.amber,
          isEnabled: guildsAllowed,
          onTap: () => _handleGatedTap(
            isEnabled: guildsAllowed,
            disabledMessage: !flags.guildsArenas
                ? 'الكتائب والبطولات الحية متوقفة مؤقتاً للصيانة والتحديث 🛡️'
                : 'تم تقييد نظام الكتائب على هذا الحساب من الإدارة 🔒',
            onProceed: () => _navigateTo(const GuildDashboardScreen()),
          ),
        ),
        const SizedBox(height: 32),
        const ChallengeInstructionsBox(),
      ],
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
                        color: AppTheme.accentColor.withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.sports_kabaddi_rounded,
                    color: AppTheme.primaryDark,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [AppTheme.accentLight, AppTheme.accentColor],
                    ).createShader(bounds),
                    child: const Text(
                      'وضع التحدي',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              SoundService().playClick();
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.accentColor.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppTheme.accentColor,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

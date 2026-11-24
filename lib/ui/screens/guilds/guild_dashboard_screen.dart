import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/cms_icon_registry.dart';
import '../../../core/sound_service.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/guild_model.dart';
import '../../../data/services/app_control_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/guild_service.dart';
import 'create_guild_dialog.dart';
import 'widgets/guild_leaderboard_tab.dart';
import 'widgets/my_guild_tab.dart';

/// شاشة الكتائب والرايات ومعركة الجمعة الكبرى الأسبوعية (5–30 عضواً).
class GuildDashboardScreen extends StatefulWidget {
  const GuildDashboardScreen({super.key});

  @override
  State<GuildDashboardScreen> createState() => _GuildDashboardScreenState();
}

class _GuildDashboardScreenState extends State<GuildDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final GuildService _guilds = GuildService.instance;
  String? _statusMsg;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _guilds.addListener(_onChanged);
    AppControlService.instance.featureFlagsNotifier.addListener(_onChanged);
    AppControlService.instance.playerPermissionsNotifier.addListener(_onChanged);
    AppControlService.instance.isAdminNotifier.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _guilds.fetchOverview();
    });
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _guilds.removeListener(_onChanged);
    AppControlService.instance.featureFlagsNotifier.removeListener(_onChanged);
    AppControlService.instance.playerPermissionsNotifier
        .removeListener(_onChanged);
    AppControlService.instance.isAdminNotifier.removeListener(_onChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openCreateDialog() async {
    SoundService().playClick();
    await showDialog<bool>(
      context: context,
      builder: (_) => const CreateGuildDialog(),
    );
  }

  Future<void> _joinGuild(GuildModel guild) async {
    SoundService().playClick();
    final err = await _guilds.joinGuild(guild.id);
    if (!mounted) return;
    setState(() {
      _statusMsg = err ?? 'تم انضمامك إلى كتيبة "${guild.name}" بنجاح 🛡️';
    });
  }

  Future<void> _leaveGuild() async {
    SoundService().playClick();
    final err = await _guilds.leaveGuild();
    if (!mounted) return;
    setState(() {
      _statusMsg = err ?? 'تمت مغادرة الكتيبة بنجاح';
    });
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final accent = customTheme.sovereignAccent;
    final control = AppControlService.instance;
    final isAdmin = control.isAdminNotifier.value;
    final isLoggedIn = AuthService().isLoggedIn;
    final flags = control.featureFlagsNotifier.value;
    final perms = control.playerPermissionsNotifier.value;
    final enabled = (isAdmin || flags.guildsArenas) &&
        (isAdmin ||
            (!perms.isEffectivelyBannedNow &&
                (!isLoggedIn || perms.canUseGuilds)));
    final disabledReason = !flags.guildsArenas
        ? 'نظام الكتائب والبطولات الجماعية متوقف مؤقتاً للصيانة.'
        : 'تم تقييد استخدام نظام الكتائب على هذا الحساب من الإدارة.';
    final data = _guilds.overview;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: customTheme.backgroundGradient),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(accent),
                if (!enabled)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          disabledReason,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white70,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: customTheme.surfaceCard.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelColor: AppTheme.primaryDark,
                        unselectedLabelColor: Colors.white70,
                        dividerColor: Colors.transparent,
                        labelStyle: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                        tabs: const [
                          Tab(text: 'كتيبتي والانضمام'),
                          Tab(text: 'معركة الجمعة 🏆'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_statusMsg != null || _guilds.lastError != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Text(
                          _statusMsg ?? _guilds.lastError!,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.amberAccent,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: _guilds.isLoading &&
                            data.myGuild == null &&
                            data.leaderboard.isEmpty
                        ? Center(child: CircularProgressIndicator(color: accent))
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              MyGuildTab(
                                data: data,
                                onRefresh: () => _guilds.fetchOverview(),
                                onOpenCreateDialog: _openCreateDialog,
                                onLeaveGuild: _leaveGuild,
                                onHostDenied: (msg) =>
                                    setState(() => _statusMsg = msg),
                              ),
                              GuildLeaderboardTab(
                                data: data,
                                onJoinGuild: _joinGuild,
                              ),
                            ],
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              SoundService().playClick();
              Navigator.of(context).pop();
            },
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الكتائب والبطولات الحية 🛡️',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: accent,
                    fontSize: 17.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'رايات من 5 إلى 30 عضواً وتحدي الجمعة الأسبوعي',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _guilds.isLoading ? null : () => _guilds.fetchOverview(),
            icon: Icon(Icons.refresh_rounded, color: accent),
          ),
        ],
      ),
    );
  }
}

class CreateGuildDialogStateIcons {
  CreateGuildDialogStateIcons._();
  static const List<IconData> all = CmsIconRegistry.guildBannerIcons;
}

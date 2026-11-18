import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/sound_service.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/guild_model.dart';
import '../../../data/services/app_control_service.dart';
import '../../../data/services/guild_service.dart';
import '../../widgets/avatar_selector.dart';
import '../live_arena/host_control_screen.dart';
import '../live_arena/student_participant_screen.dart';
import 'create_guild_dialog.dart';

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
    _tabController.dispose();
    super.dispose();
  }

  IconData _iconFor(int idx) {
    const icons = CreateGuildDialogStateIcons.all;
    return icons[idx.clamp(0, icons.length - 1)];
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
    final enabled =
        AppControlService.instance.featureFlagsNotifier.value.guildsArenas;
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
                  const Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'نظام الكتائب والبطولات الجماعية متوقف مؤقتاً للصيانة.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
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
                              _buildMyGuildTab(customTheme, accent, data),
                              _buildLeaderboardTab(customTheme, accent, data),
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

  Widget _buildMyGuildTab(
    AppCustomTheme customTheme,
    Color accent,
    GuildsOverviewData data,
  ) {
    final myGuild = data.myGuild;
    return RefreshIndicator(
      onRefresh: () => _guilds.fetchOverview(),
      color: accent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _buildLiveArenaQuickCard(customTheme, accent),
          const SizedBox(height: 14),
          if (myGuild == null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: customTheme.surfaceCard.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: accent.withValues(alpha: 0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'لست منضماً لكتيبة بعد',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: accent,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'أسّس رايتك الخاصة أو انضم لكتيبة من تصنيف «معركة الجمعة» لتوحيد نقاطكم كل أسبوع.',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white70,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      key: const Key('open_create_guild_btn'),
                      onPressed: _openCreateDialog,
                      icon: const Icon(Icons.add_moderator_rounded, size: 18),
                      label: const Text(
                        'تأسيس كتيبة جديدة 🛡️',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          height: 1.2,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: AppTheme.primaryDark,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: customTheme.surfaceCard.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: accent.withValues(alpha: 0.55)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _iconFor(myGuild.bannerIcon),
                          color: accent,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              myGuild.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: accent,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'الأعضاء: ${myGuild.membersCount}/${myGuild.maxMembers} • نقاط الأسبوع: ${myGuild.weeklyScore}',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (myGuild.description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      myGuild.description,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (myGuild.membersCount / myGuild.maxMembers).clamp(
                        0.0,
                        1.0,
                      ),
                      minHeight: 8,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _leaveGuild,
                    icon: const Icon(
                      Icons.exit_to_app_rounded,
                      size: 16,
                      color: Colors.redAccent,
                    ),
                    label: const Text(
                      'مغادرة الكتيبة',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      side: BorderSide(
                        color: Colors.redAccent.withValues(alpha: 0.45),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'أعضاء الكتيبة (${data.myMembers.length})',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: accent,
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final m in data.myMembers)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: customTheme.surfaceCard.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    ProfileAvatar(avatarIndex: m.avatarIndex, size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                          Text(
                            m.role,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '+${m.weeklyContribution} ⭐',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveArenaQuickCard(AppCustomTheme customTheme, Color accent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: customTheme.surfaceCard.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.cast_for_education_rounded, color: Color(0xFF38BDF8)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'غرف البطولات الجماعية الحية (حتى 100 متسابق) 🎓',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    key: const Key('arena_host_entry_btn'),
                    onPressed: () {
                      SoundService().playClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HostControlScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                      foregroundColor: AppTheme.primaryDark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'إنشاء بطولة (معلم)',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    key: const Key('arena_student_entry_btn'),
                    onPressed: () {
                      SoundService().playClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StudentParticipantScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      side: BorderSide(color: accent.withValues(alpha: 0.65)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'دخول برمز PIN',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab(
    AppCustomTheme customTheme,
    Color accent,
    GuildsOverviewData data,
  ) {
    final board = data.leaderboard;
    if (board.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'لا توجد كتائب مسجلة بعد — كن أول قائد يؤسس راية!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: board.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final g = board[index];
        final isMine = data.myGuild?.id == g.id;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: customTheme.surfaceCard.withValues(
              alpha: isMine ? 0.94 : 0.78,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isMine
                  ? accent
                  : Colors.white.withValues(alpha: 0.14),
              width: isMine ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: index < 3
                    ? accent
                    : Colors.white.withValues(alpha: 0.12),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: index < 3 ? AppTheme.primaryDark : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(_iconFor(g.bannerIcon), color: accent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${g.membersCount}/${g.maxMembers} عضو • ${g.weeklyScore} نقطة أسبوعية',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (data.myGuild == null && !g.isFull)
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () => _joinGuild(g),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: AppTheme.primaryDark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'انضمام',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class CreateGuildDialogStateIcons {
  CreateGuildDialogStateIcons._();
  static const List<IconData> all = [
    Icons.shield_rounded,
    Icons.mosque_rounded,
    Icons.military_tech_rounded,
    Icons.auto_awesome_rounded,
    Icons.flag_rounded,
    Icons.star_rounded,
  ];
}

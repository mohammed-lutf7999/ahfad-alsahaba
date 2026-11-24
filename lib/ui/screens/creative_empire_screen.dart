import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../core/size_config.dart';
import '../../data/local/empire_data.dart';
import 'empire/empire_backgrounds.dart';
import 'empire/empire_identity_and_team.dart';
import 'empire/empire_pavilion_section.dart';

class CreativeEmpireScreen extends StatefulWidget {
  const CreativeEmpireScreen({super.key});

  @override
  State<CreativeEmpireScreen> createState() => _CreativeEmpireScreenState();
}

class _CreativeEmpireScreenState extends State<CreativeEmpireScreen>
    with TickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _entranceController;
  bool _isDarkMode = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _toggleTheme() {
    setState(() => _isDarkMode = !_isDarkMode);
  }

  Color get _backgroundColor =>
      _isDarkMode ? const Color(0xFF001020) : const Color(0xFFF5F5F5);
  Color get _textColor => _isDarkMode ? Colors.white : Colors.black87;
  Color get _goldColor => const Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _isDarkMode
          ? AppTheme.royalOverlayStyle
          : AppTheme.lightSurfaceOverlayStyle,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: _backgroundColor,
          floatingActionButton: FloatingActionButton(
            onPressed: _toggleTheme,
            backgroundColor: _goldColor,
            child: Icon(
              _isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: Colors.black87,
            ),
          ),
          body: Stack(
            children: [
              if (_isDarkMode)
                const EmpireLegendaryBackground()
              else
                const EmpireLightBackground(),
              SafeArea(
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: EmpireImperialBackButton(
                            onTap: () => Navigator.pop(context),
                            isDark: _isDarkMode,
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: FadeTransition(
                          opacity: _entranceController,
                          child: Column(
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                color: _goldColor,
                                size: 40,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'الإمبراطورية الإبداعية',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: _goldColor,
                                  shadows: [
                                    BoxShadow(
                                      color: _goldColor.withValues(alpha: 0.5),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'Legacy of Excellence',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 14,
                                  letterSpacing: 3,
                                  color: _textColor.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: EmpireDesignerIdentityCard(isDark: _isDarkMode),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: getProportionateScreenHeight(40)),
                    ),
                    _buildSectionTitle('صرح الإنجازات'),
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => EmpirePavilionSection(
                            section: EmpireData.sections[index],
                            isDark: _isDarkMode,
                          ),
                          childCount: EmpireData.sections.length,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: getProportionateScreenHeight(40)),
                    ),
                    _buildSectionTitle('فريق الإمبراطورية'),
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          EmpireTeamMemberTile(
                            name: 'م. محمد أكرم لطف',
                            role: 'القائد التقني والمصمم',
                            details:
                                'مهندس البرمجيات المسؤول عن تخطيط وتطوير النظام بالكامل، وتصميم تجربة المستخدم، وضمان جودة الأداء.',
                            imagePath: 'assets/images/logo.png',
                            isDark: _isDarkMode,
                          ),
                          const SizedBox(height: 16),
                          EmpireTeamMemberTile(
                            name: 'م. فهمي القعاري',
                            role: 'مهندس الصوت والإبداع',
                            details:
                                'المسؤول عن الإنتاج الصوتي، التعليق الصوتي، وإضافة اللمسات الفنية السمعية التي تضفي روحاً على التطبيق.',
                            icon: Icons.mic_rounded,
                            isDark: _isDarkMode,
                          ),
                        ]),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: getProportionateScreenHeight(40)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: _goldColor, width: 4)),
            ),
            child: Text(
              title,
              style: TextStyle(
                color: _isDarkMode ? _goldColor : Colors.black87,
                fontFamily: 'Cairo',
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

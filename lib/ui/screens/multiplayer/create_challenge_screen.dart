import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/sound_service.dart';
import '../../../data/models/challenge_config.dart';
import '../../../data/services/challenge_game_service.dart';
import '../../../data/services/profile_service.dart';
import 'waiting_room_screen.dart';
import 'widgets/create_challenge_sections.dart';

/// شاشة إنشاء تحدي جديد
class CreateChallengeScreen extends StatefulWidget {
  const CreateChallengeScreen({super.key});

  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> {
  ChallengeType _selectedType = ChallengeType.bruteForce;
  String? _selectedCategoryId;
  int _questionCount = 10;
  bool _speedMode = true;
  int _maxPlayers = 4;
  bool _isCreating = false;

  static const List<ChallengeCategoryOption> _categories = [
    ChallengeCategoryOption('quran', 'القرآن', Icons.menu_book_rounded),
    ChallengeCategoryOption('hadith', 'الحديث', Icons.format_quote_rounded),
    ChallengeCategoryOption('fiqh', 'الفقه', Icons.balance_rounded),
    ChallengeCategoryOption('seerah', 'السيرة', Icons.mosque_rounded),
    ChallengeCategoryOption('history', 'التاريخ', Icons.history_edu_rounded),
    ChallengeCategoryOption('aqeedah', 'التوحيد', Icons.auto_awesome_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.imperialGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('نوع التحدي'),
                      const SizedBox(height: 12),
                      ChallengeTypeSelector(
                        selectedType: _selectedType,
                        onSelect: (type) => setState(() {
                          _selectedType = type;
                          if (type == ChallengeType.bruteForce) {
                            _selectedCategoryId = null;
                          }
                        }),
                      ),
                      if (_selectedType == ChallengeType.category) ...[
                        const SizedBox(height: 24),
                        _buildSectionTitle('اختر القسم'),
                        const SizedBox(height: 12),
                        ChallengeCategorySelector(
                          categories: _categories,
                          selectedCategoryId: _selectedCategoryId,
                          onSelect: (id) =>
                              setState(() => _selectedCategoryId = id),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _buildSectionTitle('عدد الأسئلة'),
                      const SizedBox(height: 12),
                      ChallengeQuestionCountSelector(
                        selectedCount: _questionCount,
                        onSelect: (count) =>
                            setState(() => _questionCount = count),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('الإعدادات'),
                      const SizedBox(height: 12),
                      ChallengeSettingsPanel(
                        speedMode: _speedMode,
                        maxPlayers: _maxPlayers,
                        onSpeedModeChanged: (v) =>
                            setState(() => _speedMode = v),
                        onDecrementPlayers: () {
                          if (_maxPlayers > 2) setState(() => _maxPlayers--);
                        },
                        onIncrementPlayers: () {
                          if (_maxPlayers < 8) setState(() => _maxPlayers++);
                        },
                      ),
                      const SizedBox(height: 40),
                      _buildCreateButton(),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppTheme.goldGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentColor.withAlpha(80),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: AppTheme.primaryDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppTheme.accentLight, AppTheme.accentColor],
                ).createShader(bounds),
                child: const Text(
                  'إنشاء تحدي',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              SoundService().playClick();
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accentColor.withAlpha(80)),
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildCreateButton() {
    final canCreate =
        _selectedType == ChallengeType.bruteForce || _selectedCategoryId != null;

    return GestureDetector(
      onTap: canCreate && !_isCreating ? _createChallenge : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: canCreate ? 1 : 0.5,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.accentLight, AppTheme.accentColor],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentColor.withValues(alpha: 0.4),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: _isCreating
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryDark),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, color: AppTheme.primaryDark),
                    SizedBox(width: 8),
                    Text(
                      'إنشاء التحدي',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _createChallenge() async {
    setState(() => _isCreating = true);

    final profile = ProfileService.instance.activeProfile;
    if (profile == null) {
      setState(() => _isCreating = false);
      return;
    }

    final config = ChallengeConfig(
      challengeId: ChallengeConfig.generateId(),
      hostName: profile.name,
      hostAvatarIndex: profile.avatarIndex.toString(),
      type: _selectedType,
      categoryId: _selectedCategoryId,
      questionCount: _questionCount,
      speedMode: _speedMode,
      maxPlayers: _maxPlayers,
    );

    final success = await ChallengeGameService.instance.initAsHost(config);
    if (!mounted) return;
    setState(() => _isCreating = false);

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WaitingRoomScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل إنشاء التحدي، تأكد من الأذونات'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

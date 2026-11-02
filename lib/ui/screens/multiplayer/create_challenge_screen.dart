import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/sound_service.dart';
import '../../../data/models/challenge_config.dart';
import '../../../data/services/challenge_game_service.dart';
import '../../../data/services/profile_service.dart';
import 'waiting_room_screen.dart';

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

  final List<_CategoryOption> _categories = [
    _CategoryOption('quran', 'القرآن', Icons.menu_book_rounded), // quran.json
    _CategoryOption('hadith', 'الحديث', Icons.format_quote_rounded),
    _CategoryOption('fiqh', 'الفقه', Icons.balance_rounded),
    _CategoryOption('seerah', 'السيرة', Icons.mosque_rounded), // seerah.json
    _CategoryOption('history', 'التاريخ', Icons.history_edu_rounded), // history.json
    _CategoryOption('aqeedah', 'التوحيد', Icons.auto_awesome_rounded), // aqeedah.json
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
                      // نوع التحدي
                      _buildSectionTitle('نوع التحدي'),
                      const SizedBox(height: 12),
                      _buildChallengeTypeSelector(),
                      
                      // اختيار القسم (إذا كان نوع محدد)
                      if (_selectedType == ChallengeType.category) ...[
                        const SizedBox(height: 24),
                        _buildSectionTitle('اختر القسم'),
                        const SizedBox(height: 12),
                        _buildCategorySelector(),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // عدد الأسئلة
                      _buildSectionTitle('عدد الأسئلة'),
                      const SizedBox(height: 12),
                      _buildQuestionCountSelector(),
                      
                      const SizedBox(height: 24),
                      
                      // الإعدادات الإضافية
                      _buildSectionTitle('الإعدادات'),
                      const SizedBox(height: 12),
                      _buildSettingsPanel(),
                      
                      const SizedBox(height: 40),
                      
                      // زر الإنشاء
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
          // Title and Icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppTheme.goldGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: AppTheme.accentColor.withAlpha(80), blurRadius: 10)],
                ),
                child: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryDark, size: 22),
              ),
              const SizedBox(width: 12),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppTheme.accentLight, AppTheme.accentColor],
                ).createShader(bounds),
                child: const Text(
                  'إنشاء تحدي',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          // Back button
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
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.accentColor, size: 20),
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

  Widget _buildChallengeTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildTypeOption(
            type: ChallengeType.bruteForce,
            icon: '🎲',
            title: 'القوة الغاشمة',
            subtitle: 'عشوائي من الكل',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTypeOption(
            type: ChallengeType.category,
            icon: '📚',
            title: 'قسم محدد',
            subtitle: 'اختر القسم',
          ),
        ),
      ],
    );
  }

  Widget _buildTypeOption({
    required ChallengeType type,
    required String icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () {
        SoundService().playClick();
        setState(() {
          _selectedType = type;
          if (type == ChallengeType.bruteForce) {
            _selectedCategoryId = null;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppTheme.accentColor.withOpacity(0.3),
                    AppTheme.accentColor.withOpacity(0.1),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.accentColor : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? AppTheme.accentColor : Colors.white,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final cat = _categories[index];
        final isSelected = _selectedCategoryId == cat.id;
        return GestureDetector(
          onTap: () {
            SoundService().playClick();
            setState(() => _selectedCategoryId = cat.id);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(colors: [AppTheme.accentLight, AppTheme.accentColor])
                  : null,
              color: isSelected ? null : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppTheme.accentColor : Colors.white.withOpacity(0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  cat.icon,
                  size: 20,
                  color: isSelected ? AppTheme.primaryDark : AppTheme.accentColor,
                ),
                const SizedBox(width: 8),
                Text(
                  cat.name,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? AppTheme.primaryDark : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuestionCountSelector() {
    return Row(
      children: [5, 10, 15, 20].map((count) {
        final isSelected = _questionCount == count;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              SoundService().playClick();
              setState(() => _questionCount = count);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(colors: [AppTheme.accentLight, AppTheme.accentColor])
                    : null,
                color: isSelected ? null : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppTheme.accentColor : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppTheme.primaryDark : Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSettingsPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Speed Mode
          Row(
            children: [
              Icon(Icons.speed_rounded, color: AppTheme.accentColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'نقاط السرعة',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'من يجيب أسرع يحصل على نقاط أكثر',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _speedMode,
                activeColor: AppTheme.accentColor,
                onChanged: (v) => setState(() => _speedMode = v),
              ),
            ],
          ),
          
          const Divider(color: Colors.white12),
          
          // Max Players
          Row(
            children: [
              Icon(Icons.people_rounded, color: AppTheme.accentColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الحد الأقصى للاعبين',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$_maxPlayers لاعبين',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _buildCounterButton(Icons.remove, () {
                    if (_maxPlayers > 2) setState(() => _maxPlayers--);
                  }),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '$_maxPlayers',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  _buildCounterButton(Icons.add, () {
                    if (_maxPlayers < 8) setState(() => _maxPlayers++);
                  }),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCounterButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        SoundService().playClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppTheme.accentColor.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppTheme.accentColor, size: 18),
      ),
    );
  }

  Widget _buildCreateButton() {
    final canCreate = _selectedType == ChallengeType.bruteForce || 
                      _selectedCategoryId != null;
    
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
                color: AppTheme.accentColor.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: _isCreating
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryDark))
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
    
    setState(() => _isCreating = false);

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WaitingRoomScreen()),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل إنشاء التحدي، تأكد من الأذونات'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _CategoryOption {
  final String id;
  final String name;
  final IconData icon;
  
  _CategoryOption(this.id, this.name, this.icon);
}

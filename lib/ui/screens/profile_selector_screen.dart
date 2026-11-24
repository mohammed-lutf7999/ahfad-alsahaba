import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/sound_service.dart';
import '../../data/models/player_profile_model.dart';
import '../../data/services/profile_service.dart';
import '../widgets/top_notification.dart';
import 'profile/profile_selector_card.dart';
import 'profile_setup_screen.dart';

/// Screen for viewing and switching between player profiles
class ProfileSelectorScreen extends StatefulWidget {
  const ProfileSelectorScreen({super.key});

  @override
  State<ProfileSelectorScreen> createState() => _ProfileSelectorScreenState();
}

class _ProfileSelectorScreenState extends State<ProfileSelectorScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _switchToProfile(PlayerProfile profile) async {
    if (profile.id == ProfileService.instance.activeProfile?.id) {
      Navigator.of(context).pop();
      return;
    }

    SoundService().playClick();
    await ProfileService.instance.setActiveProfile(profile.id);

    if (mounted) {
      TopNotification.showSuccess(context, 'تم التبديل إلى ${profile.name}');
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _createNewProfile() async {
    SoundService().playClick();

    if (ProfileService.instance.profiles.length >= 5) {
      TopNotification.showWarning(context, 'الحد الأقصى 5 سجلات');
      return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const ProfileSetupScreen()),
    );
    if (result == true && mounted) setState(() {});
  }

  Future<void> _editProfile(PlayerProfile profile) async {
    SoundService().playClick();
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ProfileSetupScreen(existingProfile: profile),
      ),
    );
    if (result == true && mounted) setState(() {});
  }

  Future<void> _deleteProfile(PlayerProfile profile) async {
    if (profile.id == ProfileService.instance.activeProfile?.id) {
      TopNotification.showError(context, 'لا يمكن حذف السجل النشط');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'حذف السجل',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontFamily: 'Cairo'),
        ),
        content: Text(
          'هل تريد حذف سجل "${profile.name}"؟\n\nسيتم حذف جميع التقدم والنقاط.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      SoundService().playClick();
      await ProfileService.instance.deleteProfile(profile.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ProfileService.instance.profiles;
    final activeId = ProfileService.instance.activeProfile?.id;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.imperialGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: FadeTransition(
                  opacity: _animController,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: profiles.length + 1,
                    itemBuilder: (context, index) {
                      if (index == profiles.length) {
                        return _buildAddProfileButton();
                      }
                      final profile = profiles[index];
                      return ProfileSelectorCard(
                        profile: profile,
                        isActive: profile.id == activeId,
                        index: index,
                        animController: _animController,
                        onSelect: () => _switchToProfile(profile),
                        onEdit: () => _editProfile(profile),
                        onDelete: () => _deleteProfile(profile),
                      );
                    },
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
                  Icons.switch_account_rounded,
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
                  'اختر سجلك',
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
              Navigator.of(context).pop();
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.1),
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

  Widget _buildAddProfileButton() {
    final canAdd = ProfileService.instance.profiles.length < 5;

    return GestureDetector(
      onTap: canAdd ? _createNewProfile : null,
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 20),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: canAdd
              ? AppTheme.accentColor.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: canAdd
                ? AppTheme.accentColor.withValues(alpha: 0.5)
                : Colors.grey.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              color: canAdd ? AppTheme.accentColor : Colors.grey,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'إضافة سجل جديد',
              style: TextStyle(
                color: canAdd ? AppTheme.accentColor : Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

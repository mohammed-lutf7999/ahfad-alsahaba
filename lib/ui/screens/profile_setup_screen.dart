import 'package:flutter/material.dart';
import '../../core/app_routes.dart';
import '../../core/app_theme.dart';
import '../../core/sound_service.dart';
import '../../data/local/shared_prefs_service.dart';
import '../../data/models/player_profile_model.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/profile_service.dart';
import '../widgets/avatar_selector.dart';
import '../widgets/top_notification.dart';
import 'profile/profile_setup_sections.dart';

/// Screen for creating or editing a player profile
class ProfileSetupScreen extends StatefulWidget {
  final PlayerProfile? existingProfile;
  final bool isFirstTime;

  const ProfileSetupScreen({
    super.key,
    this.existingProfile,
    this.isFirstTime = false,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  int _selectedAvatarIndex = 0;
  bool _isSaving = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    if (widget.existingProfile != null) {
      _nameController.text = widget.existingProfile!.name;
      _selectedAvatarIndex = widget.existingProfile!.avatarIndex;
    }

    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      TopNotification.showError(context, 'يرجى إدخال اسمك');
      return;
    }
    if (name.length < 2) {
      TopNotification.showError(context, 'الاسم قصير جداً');
      return;
    }

    setState(() => _isSaving = true);
    SoundService().playClick();

    try {
      if (widget.existingProfile != null) {
        widget.existingProfile!.name = name;
        widget.existingProfile!.avatarIndex = _selectedAvatarIndex;
        await ProfileService.instance.updateProfile(widget.existingProfile!);
      } else {
        final profile = await ProfileService.instance.createProfile(
          name: name,
          avatarIndex: _selectedAvatarIndex,
        );
        await ProfileService.instance.setActiveProfile(profile.id);
        await SharedPrefsService.setProfileSetupComplete(true);

        if (!ProfileService.instance.hasProfiles) {
          debugPrint('⚠️ Profile verification failed! Force saving...');
          await ProfileService.instance.saveActiveProfile();
        }
      }

      if (mounted) {
        if (widget.isFirstTime) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.home);
        } else {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      debugPrint('ProfileSetupScreen save error: $e');
      if (mounted) TopNotification.showError(context, 'حدث خطأ أثناء الحفظ');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    SoundService().playClick();
    setState(() => _isSaving = true);

    try {
      final result = await AuthService().signInWithGoogle();
      if (!mounted) return;
      if (result.success) {
        final activeProfile = ProfileService.instance.activeProfile;
        if (activeProfile != null &&
            _selectedAvatarIndex != activeProfile.avatarIndex) {
          activeProfile.avatarIndex = _selectedAvatarIndex;
          await ProfileService.instance.updateProfile(activeProfile);
        }
        await SharedPrefsService.setProfileSetupComplete(true);

        if (mounted) {
          TopNotification.showSuccess(
            context,
            'مرحباً ${AuthService().userDisplayName}! 🎉',
          );
          Navigator.of(context).pushReplacementNamed(AppRoutes.home);
        }
      } else {
        TopNotification.showError(context, result.errorMessage ?? 'حدث خطأ');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingProfile != null;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.imperialGradient),
        child: SafeArea(
          child: Column(
            children: [
              ProfileSetupHeader(
                isEditing: isEditing,
                isFirstTime: widget.isFirstTime,
              ),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ProfileAvatarPreview(
                            avatarIndex: _selectedAvatarIndex,
                          ),
                          const SizedBox(height: 32),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: AppTheme.cardGradient,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color:
                                    AppTheme.accentColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                AvatarSelector(
                                  selectedIndex: _selectedAvatarIndex,
                                  onSelected: (index) => setState(
                                    () => _selectedAvatarIndex = index,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Container(
                                  height: 1,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        AppTheme.accentColor
                                            .withValues(alpha: 0.5),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ProfileNameInput(controller: _nameController),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          ProfileSaveButton(
                            isEditing: isEditing,
                            isSaving: _isSaving,
                            onPressed: _saveProfile,
                          ),
                          if (widget.isFirstTime &&
                              !AuthService().isLoggedIn) ...[
                            const SizedBox(height: 24),
                            ProfileGoogleSignInSection(
                              onSignIn: _signInWithGoogle,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../widgets/top_notification.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../core/app_routes.dart';
import '../../core/sound_service.dart';
import '../../data/services/profile_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/models/player_profile_model.dart';
import '../../data/local/shared_prefs_service.dart';
import '../widgets/avatar_selector.dart';

/// Screen for creating or editing a player profile
class ProfileSetupScreen extends StatefulWidget {
  final PlayerProfile? existingProfile; // null = create new, non-null = edit
  final bool isFirstTime; // true = navigated from app start (no back button)

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
    
    // Pre-populate if editing
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
      _showError('يرجى إدخال اسمك');
      return;
    }
    
    if (name.length < 2) {
      _showError('الاسم قصير جداً');
      return;
    }
    
    setState(() => _isSaving = true);
    SoundService().playClick();
    
    try {
      if (widget.existingProfile != null) {
        // Update existing profile
        widget.existingProfile!.name = name;
        widget.existingProfile!.avatarIndex = _selectedAvatarIndex;
        await ProfileService.instance.updateProfile(widget.existingProfile!);
      } else {
        // Create new profile
        final profile = await ProfileService.instance.createProfile(
          name: name,
          avatarIndex: _selectedAvatarIndex,
        );
        // Set as active
        await ProfileService.instance.setActiveProfile(profile.id);
        await SharedPrefsService.setProfileSetupComplete(true);
        
        // 🔍 Precaution: Verify persistence
        if (!ProfileService.instance.hasProfiles) {
           debugPrint('⚠️ Profile verification failed! Force saving...');
           await ProfileService.instance.saveActiveProfile();
        }
      }
      
      if (mounted) {
        if (widget.isFirstTime) {
          // Navigate to home
          Navigator.of(context).pushReplacementNamed(AppRoutes.home);
        } else {
          Navigator.of(context).pop(true); // Return success
        }
      }
    } catch (e) {
      _showError('حدث خطأ أثناء الحفظ');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    TopNotification.showError(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingProfile != null;
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: AppTheme.imperialGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(isEditing),
              
              // Content
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
                          // Large Avatar Preview
                          _buildAvatarPreview(),
                          
                          const SizedBox(height: 32),
                          
                          // Avatar Selection
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: AppTheme.cardGradient,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.accentColor.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                // Avatar Selector
                                AvatarSelector(
                                  selectedIndex: _selectedAvatarIndex,
                                  onSelected: (index) {
                                    setState(() => _selectedAvatarIndex = index);
                                  },
                                ),
                                
                                const SizedBox(height: 24),
                                
                                // Divider
                                Container(
                                  height: 1,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        AppTheme.accentColor.withValues(alpha: 0.5),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 24),
                                
                                // Name Input
                                _buildNameInput(),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Save Button
                          _buildSaveButton(isEditing),
                          
                          // Google Sign-In Option (for first time users)
                          if (widget.isFirstTime && !AuthService().isLoggedIn) ...[
                            const SizedBox(height: 24),
                            _buildGoogleSignInButton(),
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

  Widget _buildHeader(bool isEditing) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (!widget.isFirstTime)
            IconButton(
              onPressed: () {
                SoundService().playClick();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            )
          else
            const SizedBox(width: 48),
          
          Expanded(
            child: Text(
              isEditing ? 'تعديل الملف الشخصي' : 'إنشاء ملف شخصي',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
          ),
          
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildAvatarPreview() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.goldGradient,
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentColor.withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ProfileAvatar(
        avatarIndex: _selectedAvatarIndex,
        size: 100,
      ),
    );
  }

  Widget _buildNameInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'اسمك',
          style: TextStyle(
            color: AppTheme.accentColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'أدخل اسمك هنا',
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 16,
            ),
            filled: true,
            fillColor: AppTheme.primaryDark.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: AppTheme.accentColor.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            prefixIcon: const Icon(
              Icons.person_rounded,
              color: AppTheme.accentColor,
            ),
          ),
          inputFormatters: [
            LengthLimitingTextInputFormatter(20),
          ],
        ),
      ],
    );
  }

  Widget _buildSaveButton(bool isEditing) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.goldGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentColor.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveProfile,
          icon: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryDark,
                  ),
                )
              : Icon(
                  isEditing ? Icons.save_rounded : Icons.check_rounded,
                  color: AppTheme.primaryDark,
                ),
          label: Text(
            isEditing ? 'حفظ التغييرات' : 'ابدأ اللعب',
            style: const TextStyle(
              color: AppTheme.primaryDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return Column(
      children: [
        // Divider with "أو"
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'أو',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 20),
        
        // Google Sign-In Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _signInWithGoogle,
            icon: Image.network(
              'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
              width: 24,
              height: 24,
              errorBuilder: (_, __, ___) => const Icon(Icons.login_rounded, color: Colors.white),
            ),
            label: const Text(
              'تسجيل الدخول بحساب Google',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Cairo',
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Info text
        Text(
          'سيتم ربط حسابك بـ Google للمنافسة عالمياً',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }

  Future<void> _signInWithGoogle() async {
    SoundService().playClick();
    setState(() => _isSaving = true);
    
    try {
      final result = await AuthService().signInWithGoogle();
      
      if (mounted) {
        if (result.success) {
          // Profile is automatically created/loaded by AuthService.signInWithGoogle()
          // Just update the avatar if user selected one
          final activeProfile = ProfileService.instance.activeProfile;
          if (activeProfile != null && _selectedAvatarIndex != activeProfile.avatarIndex) {
            activeProfile.avatarIndex = _selectedAvatarIndex;
            await ProfileService.instance.updateProfile(activeProfile);
          }
          
          await SharedPrefsService.setProfileSetupComplete(true);
          
          if (mounted) {
            TopNotification.showSuccess(context, 'مرحباً ${AuthService().userDisplayName}! 🎉');
            Navigator.of(context).pushReplacementNamed(AppRoutes.home);
          }
        } else {
          TopNotification.showError(context, result.errorMessage ?? 'حدث خطأ');
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

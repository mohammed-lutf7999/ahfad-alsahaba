import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/app_theme.dart';
import '../../../core/sound_service.dart';
import '../../widgets/avatar_selector.dart';

class ProfileSetupHeader extends StatelessWidget {
  final bool isEditing;
  final bool isFirstTime;

  const ProfileSetupHeader({
    super.key,
    required this.isEditing,
    required this.isFirstTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (!isFirstTime)
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
}

class ProfileAvatarPreview extends StatelessWidget {
  final int avatarIndex;

  const ProfileAvatarPreview({super.key, required this.avatarIndex});

  @override
  Widget build(BuildContext context) {
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
      child: ProfileAvatar(avatarIndex: avatarIndex, size: 100),
    );
  }
}

class ProfileNameInput extends StatelessWidget {
  final TextEditingController controller;

  const ProfileNameInput({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
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
          controller: controller,
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
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
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
          inputFormatters: [LengthLimitingTextInputFormatter(20)],
        ),
      ],
    );
  }
}

class ProfileSaveButton extends StatelessWidget {
  final bool isEditing;
  final bool isSaving;
  final VoidCallback onPressed;

  const ProfileSaveButton({
    super.key,
    required this.isEditing,
    required this.isSaving,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
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
          onPressed: isSaving ? null : onPressed,
          icon: isSaving
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
              height: 1.2,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileGoogleSignInSection extends StatelessWidget {
  final VoidCallback onSignIn;

  const ProfileGoogleSignInSection({super.key, required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'أو',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: onSignIn,
            icon: Image.network(
              'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
              width: 24,
              height: 24,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.login_rounded, color: Colors.white),
            ),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'تسجيل الدخول بحساب Google',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Cairo',
                  height: 1.2,
                ),
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
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
}

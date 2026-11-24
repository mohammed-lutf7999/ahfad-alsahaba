import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/sound_service.dart';

/// Styled menu card for a multiplayer/challenge mode entry on [ChallengeMenuScreen].
class ChallengeModeCard extends StatelessWidget {
  const ChallengeModeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.isEnabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isEnabled ? color : Colors.blueGrey.shade300;
    return GestureDetector(
      onTap: () {
        SoundService().playClick();
        onTap();
      },
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.72,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                effectiveColor.withValues(alpha: 0.2),
                effectiveColor.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: effectiveColor.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: effectiveColor.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isEnabled ? icon : Icons.lock_clock_rounded,
                  color: effectiveColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: effectiveColor,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.65),
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isEnabled
                    ? Icons.arrow_forward_ios_rounded
                    : Icons.lock_outline_rounded,
                color: effectiveColor.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top glowing VS emblem & footer instructions box for [ChallengeMenuScreen].
class ChallengeVsEmblem extends StatelessWidget {
  const ChallengeVsEmblem({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppTheme.accentColor.withValues(alpha: 0.3),
            Colors.transparent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentColor.withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Center(
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppTheme.accentLight, AppTheme.accentColor],
          ).createShader(bounds),
          child: const Text(
            'VS',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class ChallengeInstructionsBox extends StatelessWidget {
  const ChallengeInstructionsBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.white.withValues(alpha: 0.5),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'كيفية التحدي',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• غرف التحدي الخاصة والميدان السريع تعمل عبر الإنترنت مباشرة دون أذونات\n'
            '• تحدي البلوتوث مخصص للتنافس المحلي بدون إنترنت في نفس المكان',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
              height: 1.5,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}

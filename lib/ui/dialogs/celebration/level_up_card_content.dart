import 'package:flutter/material.dart';
import '../../../data/services/progression_service.dart';
import '../../widgets/animated_avatar_frame.dart';
import '../../widgets/level_badge_widget.dart';

class LevelUpCardContent extends StatelessWidget {
  final LevelUpTransition transition;
  final VoidCallback onContinue;
  final VoidCallback onShare;

  const LevelUpCardContent({
    super.key,
    required this.transition,
    required this.onContinue,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final newLevel = transition.newLevel;
    final oldLevel = transition.oldLevel;
    final primary = newLevel.badgeColor;
    final secondary = newLevel.secondaryColor;

    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF140B29).withValues(alpha: 0.96),
            Color.lerp(const Color(0xFF0A192F), primary, 0.28)!
                .withValues(alpha: 0.96),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: secondary.withValues(alpha: 0.85), width: 2.0),
        boxShadow: [
          BoxShadow(
            color: secondary.withValues(alpha: 0.35),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: secondary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: secondary.withValues(alpha: 0.65)),
              ),
              child: const Text(
                '✨ ارتقاء أسطوري في مدارج المجد ✨',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Color(0xFFF3C644),
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 18),
            AnimatedAvatarFrame(
              frameKey: newLevel.frameKey,
              level: newLevel.level,
              size: 96,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [secondary.withValues(alpha: 0.9), primary],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(newLevel.tierIcon, color: Colors.white, size: 26),
                      Text(
                        '${newLevel.level}',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          height: 1.05,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'بلغت المستوى ${newLevel.level}!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'من المستوى ${oldLevel.level} ⬅ إلى المستوى ${newLevel.level}',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white.withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            LevelBadgeWidget(levelInfo: newLevel, isCompact: false),
            if (transition.isNewTitleUnlocked) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.6),
                  ),
                ),
                child: Text(
                  '🎉 فُتح لقب وإطار ملكي جديد: «${newLevel.frameName}»',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Color(0xFF6EE7B7),
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                    height: 1.2,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFF3C644).withValues(alpha: 0.55),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.monetization_on_rounded,
                    color: Color(0xFFF3C644),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'منحة الترقية: +${transition.coinsAwarded} دينار فتح 🪙',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Color(0xFFF3C644),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF3C644),
                  foregroundColor: const Color(0xFF140B29),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.bolt_rounded, size: 20),
                label: const Text(
                  'متابعة المسيرة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    height: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: onShare,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: secondary.withValues(alpha: 0.75),
                    width: 1.3,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text(
                  'مشاركة الفخر 📲',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

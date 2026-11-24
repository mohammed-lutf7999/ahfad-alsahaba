import 'package:flutter/material.dart';
import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/player_level_model.dart';
import '../../../widgets/animated_avatar_frame.dart';
import '../../../widgets/level_badge_widget.dart';

class StoreClosedView extends StatelessWidget {
  final AppCustomTheme customTheme;

  const StoreClosedView({super.key, required this.customTheme});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: customTheme.surfaceCard.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: customTheme.sovereignAccent.withValues(alpha: 0.55),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.storefront_outlined,
                  size: 52,
                  color: customTheme.sovereignAccent,
                ),
                const SizedBox(height: 14),
                const Text(
                  'سوق الفرسان مغلق مؤقتاً',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'يخضع المتجر حالياً لتحديثات وتجهيز مقتنيات جديدة بإذن الله.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13.5,
                    height: 1.5,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: customTheme.sovereignAccent,
                      foregroundColor: const Color(0xFF0A1428),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text(
                      'العودة',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StoreWalletHeader extends StatelessWidget {
  final AppCustomTheme customTheme;
  final PlayerLevelInfo levelInfo;
  final String equippedFrame;
  final String? customTitle;
  final int coins;
  final int gems;
  final int winStreak;

  const StoreWalletHeader({
    super.key,
    required this.customTheme,
    required this.levelInfo,
    required this.equippedFrame,
    this.customTitle,
    required this.coins,
    required this.gems,
    required this.winStreak,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: customTheme.surfaceCard.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: customTheme.sovereignAccent.withValues(alpha: 0.6),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedAvatarFrame(
            frameKey: equippedFrame,
            level: levelInfo.level,
            winStreak: winStreak,
            size: 54,
            child: Container(
              color: customTheme.deepBackground,
              child: Icon(
                Icons.person_rounded,
                color: customTheme.sovereignAccent,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الثيم النشط: ${customTheme.themeName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                LevelBadgeWidget(
                  levelInfo: levelInfo,
                  customTitle: customTitle,
                  isCompact: true,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                key: const Key('wallet_coins_badge'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.38),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFFF3C644).withValues(alpha: 0.65),
                  ),
                ),
                child: Text(
                  '$coins 🪙',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Color(0xFFF3C644),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                key: const Key('wallet_gems_badge'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.38),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.65),
                  ),
                ),
                child: Text(
                  '$gems 💎',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Color(0xFF38BDF8),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
